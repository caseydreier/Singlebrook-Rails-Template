# Singlebrook Rails Template
# v 0.0.1 by Casey Dreier

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

# ========
# = Gems =
# ========

# Testing-related
gem 'factory_girl', :version => "1.2.4"
gem 'mocha'

# Pagination
gem 'will_paginate', :version => '~> 2.3.11'

# Exception Handling
gem 'exception_notification', :version => '2.3.3'

# Authentication
gem 'authlogic', :version => '~> 2.1.5'

# ===========
# = Plugins =
# ===========

plugin 'jrails', :git => "git://github.com/aaronchi/jrails.git"
plugin 'validates_timeliness', :git => 'git://github.com/adzap/validates_timeliness.git'

# ====================
# = Capistrano Setup =
# ====================

# deployment
capify!

file 'config/deploy.rb', <<-END
set :application, "#{current_app_name}"
set :repository,  "https://svn.singlebrook.com/svn/missionmarkets/#{current_app_name}/trunk"
set :tags_repository,  "https://svn.singlebrook.com/svn/missionmarkets/#{current_app_name}/tags"

set :scm, :subversion
set :scm_username, ""
set :scm_password, ""

# Customise the deployment
set :tag_on_deploy, false # turn off deployment tagging, we have our own tagging strategy

set :keep_releases, 6
after "deploy:update", "deploy:cleanup"

set :user, ""
set :use_sudo, false
server "", :app, :web, :db, :primary => true

# directories to preserve between deployments
# set :asset_directories, ['public/assets']

# re-linking for config files on public repos  
# namespace :deploy do
#   desc "Re-link config files"
#   task :link_config, :roles => :app do
#     run "ln -nsf \#{shared_path}/config/database.yml \#{current_path}/config/database.yml"
#   end

namespace :deploy do
  task :start do ; end
  task :stop do ; end
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "\#{try_sudo} touch \#{File.join(current_path,'tmp','restart.txt')}"
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
set :stages, %w(staging production)
set :default_stage, "staging"
require 'capistrano/ext/multistage'

load 'config/deploy'

}

# ===============
# = Application =
# ===============

file 'app/helpers/layout_helper.rb', 
%q{# These helper methods can be called in your template to set variables to be used in the layout
# This module should be included in all views globally,
# to do so you may need to add this line to your ApplicationController
#   helper :layout or helper :all
module LayoutHelper
  def title(page_title)
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

file 'app/views/layouts/application.html.erb', 
%q{<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" 
  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
  <head>
    <meta http-equiv="Content-type" content="text/html; charset=utf-8" />
    <title><%= yield :page_title %></title>
    <%= stylesheet_link_tag 'screen', :media => 'all', :cache => true %>
    <%= javascript_include_tag :defaults, :cache => true %>
    <%= yield :head -%>
  </head>
  <body>
    <%= render :partial => 'layouts/flashes' -%>
    <%= yield %>
  </body>
</html>
}

file 'app/views/layouts/_flashes.html.erb', 
%q{<div id="flash">
  <% flash.each do |key, value| -%>
    <div id="flash_<%= key %>"><%=h value %></div>
  <% end -%>
</div>
}

file 'app/controllers/application_controller.rb',
%q{class ApplicationController < ActionController::Base
  # Exception Notification for app.
  include ExceptionNotification::Notifiable
  
  helper :all # include all helpers, all the time
  protect_from_forgery # See ActionController::RequestForgeryProtection for details

  # See ActionController::Base for details 
  # Uncomment this to filter the contents of submitted sensitive data parameters
  # from your application log (in this case, all fields with names like "password"). 
  filter_parameter_logging :password, :confirm_password, :password_confirmation, :creditcard

  
  # Catch any Error404 exceptions and trigger a 404 page to render
  rescue_from Error404, :with => :render_404
  
  # Authlogic methods
  def logged_in?
    !current_user_session.nil?
  end

  def admin_required
    unless current_user && current_user.admin?
      flash[:error] = "Sorry, you don't have access to that."
      redirect_to root_url and return false
    end
  end

  def admin_logged_in?
    logged_in? && current_user.admin?
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
      redirect_to account_url
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
end

class ActionController::TestCase
  setup :activate_authlogic
end
}

# Final install steps
rake('gems:install', :sudo => true)
rake('db:migrate')
