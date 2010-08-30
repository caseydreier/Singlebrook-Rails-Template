# Singlebrook Rails Template
# v 0.1.0 by Casey Dreier

current_app_name = File.basename(File.expand_path(root))

# Delete unnecessary files
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
run "rm public/images/rails.png"

run "touch public/stylesheets/screen.css"

# remove prototype js
run "rm -f public/javascripts/*"

# Download JQuery
run "curl -s -L http://code.jquery.com/jquery-1.4.2.min.js > public/javascripts/jquery.js"

# Copy database.yml for distribution use
run "cp config/database.yml config/database.yml.example"

# Set up .gitignore files, for those lucky few of us using Git
run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
file '.gitignore', <<-END
.DS_Store
log/*.log
tmp/**/*
config/database.yml
db/*.sqlite3
tmp/restart.txt
END


# ================
# = Initializers =
# ================

# Create Custom Exception for 404s in initializers
initializer 'custom_exceptions.rb',
%q{# Custom 404 Error class
  class Error404 < StandardError; end;
}

# Reset default time formats
initializer 'time_formats.rb',
%q{# Example time formats
{ :short_date => "%x", :long_date => "%a, %b %d, %Y" }.each do |k, v|
  ActiveSupport::CoreExtensions::Time::Conversions::DATE_FORMATS.update(k => v)
end
}

# ================
# = Environments =
# ================

file 'config/environments/development.rb',
%q{# Settings specified here will take precedence over those in config/environment.rb

# In the development environment your application's code is reloaded on
# every request.  This slows down response time but is perfect for development
# since you don't have to restart the webserver when you make code changes.
config.cache_classes = false

# Log error messages when you accidentally call methods on nil.
config.whiny_nils = true

# Show full error reports and disable caching
config.action_controller.consider_all_requests_local = true
config.action_view.debug_rjs                         = true
config.action_controller.perform_caching             = false

# Don't bother raising an error if the mailer can't send in dev mode
config.action_mailer.raise_delivery_errors = false

# Display ActiveRecord logging in terminal STDOUT
if $0 == 'irb'
  ActiveRecord::Base.logger = Logger.new(STDOUT)
end
}

# ==========
# = Routes =
# ==========

# Routes for Authlogic
route "map.resources :user_sessions, :only => [:new, :create, :destroy]"
route 'map.login "/login",   :controller => "user_sessions", :action => "new"'
route 'map.logout "/logout", :controller => "user_sessions", :action => "destroy"'

# ========
# = Gems =
# ========

# Testing-related
gem 'factory_girl', :version => "1.2.4"
gem 'mocha'

# Pagination
gem 'will_paginate', :version => '~> 2.3.14'

# Exception Handling
gem 'exception_notification', :version => '2.3.3'

# Authentication
gem 'authlogic', :version => '~> 2.1.5'

# Erubis ERB rendering engine for Rails XSS plugin
gem 'erubis'

# HAML by default!
gem 'haml'


# ===========
# = Plugins =
# ===========

plugin 'jrails', :git => "git://github.com/aaronchi/jrails.git"
plugin 'validates_timeliness', :git => 'git://github.com/adzap/validates_timeliness.git'
plugin 'rails_xss', :git => 'git://github.com/rails/rails_xss.git'

# ====================
# = Capistrano Setup =
# ====================

# deployment
capify!

file 'config/deploy.rb', <<-END
set :stages, %w(staging production)
set :default_stage, "staging"

require 'capistrano/ext/multistage'

set :application, "#{current_app_name}"
set :repository,  "http://git.singlebrook.com/git/#{current_app_name}"

set :scm, :git
set :scm_username, ""
set :scm_password, ""
set :deploy_via, :remote_cache

# Customise the deployment
set :tag_on_deploy, false # turn off deployment tagging, we have our own tagging strategy

set :keep_releases, 6
after "deploy:update", "deploy:cleanup"

set :user, ""
set :use_sudo, false
server "", :app, :web, :db, :primary => true

# directories to preserve between deployments
set :asset_directories, ['public/assets']

# re-linking for config files on public repos
namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "#{try_sudo} touch #{File.join(current_path,'tmp','restart.txt')}"
  end

  desc "Re-link config files"
  task :link_config_files, :roles => :app do
    run "ln -nsf #{config_path}/database.yml #{release_path}/config/database.yml"
  end

  after "deploy:update_code", "deploy:link_config_files"

end

namespace :gems do
  desc "Install gems"
  task :install, :roles => :app do
    run "cd #{current_path} && #{try_sudo} rake gems:install RAILS_ENV=#{rails_env}"
  end
end

END

file 'config/deploy/production.rb', <<-END
set :rails_env, "development"
set :deploy_to, ""

END

file 'config/deploy/staging.rb', <<-END
set :rails_env, "development"
set :deploy_to, ""
END

file 'Capfile',
%q{load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

load 'config/deploy'

}

# ===============
# = Application =
# ===============

# Generate Authlogic user session model
generate("session", "user_session")

file 'app/helpers/layout_helper.rb',
%q{# These helper methods can be called in your template to set variables to be used in the layout
# This module should be included in all views globally,
# to do so you may need to add this line to your ApplicationController
#   helper :layout or helper :all
module LayoutHelper
  def page_title(page_title)
    content_for(:page_title) { page_title.to_s }
  end

  def stylesheet(*args)
    content_for(:head) { stylesheet_link_tag(*args) }
  end

  def javascript(*args)
    content_for(:head) { javascript_include_tag(*args) }
  end
end

}

file 'app/views/layouts/application.html.haml',
%q{!!!
%html
  %head
    %title
      = yield :page_title
    = stylesheet_link_tag 'screen', :media => 'all', :cache => true
    = javascript_include_tag :defaults, :cache => true
    = yield :head
  %body
    = render :partial => 'layouts/flashes'
    = yield
}

file 'app/views/layouts/_flashes.html.haml',
%q{#flash
  - flash.each do |key,value|
    %div{:id=> "flash_#{key}"}
      = value
}

file 'app/controllers/application_controller.rb',
%q{class ApplicationController < ActionController::Base
  # Exception Notification for app.
  include ExceptionNotification::Notifiable
  include Authlogic::ApplicationControllerMethods # custom lib

  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # Filter out sensitive information from our logs
  filter_parameter_logging :password, :confirm_password, :password_confirmation, :creditcard

  # Catch any Error404 exceptions and trigger a 404 page to render
  rescue_from Error404, :with => :render_404

  # make some authlogic methods available to views
  helper_method :logged_in?, :current_user_session, :current_user


  # Return a 404 in the HTTP headers and optionally render 404 not found page if the
  # request was for HTML.
  def render_404
    respond_to do |format|
      format.html { render :file => "#{File.join(Rails.root,'public','404.html')}", :status => 404 }
      format.all  { render :nothing => true, :status => 404 }
    end
    true
  end


end
}

run "script/generate model User --skip-fixture --skip-migration"
file 'app/models/user.rb',
%q{class User < ActiveRecord::Base
  acts_as_authentic # for available options see documentation in: Authlogic::ActsAsAuthentic
end
}

file 'db/migrate/20100625202151_create_users.rb',
%q{class CreateUsers < ActiveRecord::Migration
  def self.up
    create_table :users do |t|
      t.string    :login,               :null => false                # optional, you can use email instead, or both
      t.string    :email,               :null => false                # optional, you can use login instead, or both
      t.string    :first_name
      t.string    :last_name
      t.string    :crypted_password,    :null => false                # optional, see below
      t.string    :password_salt,       :null => false                # optional, but highly recommended
      t.string    :persistence_token,   :null => false                # required
      t.string    :single_access_token, :null => false                # optional, see Authlogic::Session::Params
      t.string    :perishable_token,    :null => false                # optional, see Authlogic::Session::Perishability

      # Magic columns, just like ActiveRecord's created_at and updated_at. These are automatically maintained by Authlogic if they are present.
      t.integer   :login_count,         :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
      t.integer   :failed_login_count,  :null => false, :default => 0 # optional, see Authlogic::Session::MagicColumns
      t.datetime  :last_request_at                                    # optional, see Authlogic::Session::MagicColumns
      t.datetime  :current_login_at                                   # optional, see Authlogic::Session::MagicColumns
      t.datetime  :last_login_at                                      # optional, see Authlogic::Session::MagicColumns
      t.string    :current_login_ip                                   # optional, see Authlogic::Session::MagicColumns
      t.string    :last_login_ip                                      # optional, see Authlogic::Session::MagicColumns
      t.timestamps
    end
  end

  def self.down
    drop_table :users
  end
end
}

file 'app/controllers/user_sessions_controller.rb',
%q{class UserSessionsController < ApplicationController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy

  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      redirect_to account_url
    else
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    redirect_to new_user_session_url
  end
end
}

file 'app/views/user_sessions/new.html.haml',
%q{- page_title 'Login'
%h1 Login

- form_for @user_session do |f|
  = f.error_messages
  = f.label :login
  %br
  = f.text_field :login
  %br
  = f.label :password
  %br
  = f.password_field :password
  %br
  = f.submit "Login"
}

file 'lib/authlogic/application_controller_methods.rb',
%q{module Authlogic
  module ApplicationControllerMethods
    def logged_in?
      !current_user_session.nil?
    end

  private
    def current_user_session
      return @current_user_session if defined?(@current_user_session)
      @current_user_session = UserSession.find
    end

    def current_user
      return @current_user if defined?(@current_user)
      @current_user = current_user_session && current_user_session.user
    end

    def require_user
      unless current_user
        store_location
        flash[:notice] = "You must be logged in to access this page"
        redirect_to new_user_session_url
        return false
      end
    end

    def require_no_user
      if current_user
        store_location
        flash[:notice] = "You must be logged out to access this page"
        redirect_back_or_default root_url
        return false
      end
    end

    def store_location
      session[:return_to] = request.request_uri
    end

    def redirect_back_or_default(default)
      redirect_to(session[:return_to] || default)
      session[:return_to] = nil
    end
  end
end
}

# ==========================
# = Testing-releated Files =
# ==========================

file 'test/test_helper.rb',
%q{ENV["RAILS_ENV"] = "test" if ENV["RAILS_ENV"].nil? || ENV["RAILS_ENV"] == ''
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require 'test_help'
require 'mocha'
require 'authlogic/test_case'

class ActiveSupport::TestCase

  self.use_transactional_fixtures = true
  self.use_instantiated_fixtures  = false

  # Add more helper methods to be used by all tests here...

  # This is the opposite of "assert", but it reads a little nicer.
  def deny(*args)
    !assert(args)
  end

  # Asserts a specific layout in a functional test
  def assert_layout(layout)
    assert_equal layout, @response.layout
  end

  # Assert that a specified route does not exist
  def assert_not_routing(path, options, defaults={}, extras={}, message=nil)
    assert_raise ActionController::RoutingError do
      assert_routing(path, options, defaults, extras, message)
    end
  end

  # Helper Method for setting the requesting host
  # Mocks the proper response for the domain() method, as well as the
  # @request.host value.
  def set_test_host(host)
    @request.host = host
    domain = host.split('.').last(2).join('.')
    ActionController::TestRequest.any_instance.stubs(:domain).returns(domain)
  end

  # Helper method to login users for our functional tests.
  def login_as(user_obj)
    UserSession.create(user_obj)
  end

end

class ActionController::TestCase
  setup :activate_authlogic
end
}

# User Factory
file 'test/factories/users.rb',
%q{# Factory.define :user do |f|
  # f.sequence(:email)      {|n| "joey#{n}@aol.com"}
  # f.sequence(:login)      {|n| "joeyl337#{n}"}
  # f.first_name            'Joey Joe Joe'
  # f.last_name             'Johnson Jr.'
  # f.password              '123123'
  # f.password_confirmation '123123'
  # f.password_salt         { Authlogic::Random.hex_token}
  # f.crypted_password      { Authlogic::CryptoProviders::Sha512.encrypt("sb" + salt) }
  # f.persistence_token     { Authlogic::Random.hex_token }
  # f.single_access_token   { Authlogic::Random.friendly_token }
  # f.perishable_token      { Authlogic::Random.friendly_token }
# end
}

# Final install steps
rake('gems:install', :sudo => true) if yes?("Would you like to run rake gems:install? (yes/no)")
rake('db:migrate') if yes?("Would you like to run migrations? (yes/no)")