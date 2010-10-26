# Singlebrook Rails Template
# v 0.2.0 by Casey Dreier
# based on a scaffold from http://railswizard.org/

# =================
# = Initial Setup =
# =================
require 'rubygems'
require 'active_support/core_ext'

initializer 'generators.rb', <<-RUBY
Rails.application.config.generators do |g|
end
RUBY

def say_recipe(name); say "\033[36m" + "recipe".rjust(10) + "\033[0m" + "    Running #{name} recipe..." end
def say_wizard(text); say "\033[36m" + "wizard".rjust(10) + "\033[0m" + "    #{text}" end

@after_blocks = []
def after_bundler(&block); @after_blocks << block; end

# Delete unnecessary files
say_wizard("Removing unnecessary files")
run "rm README"
run "rm public/index.html"
run "rm public/favicon.ico"
run "rm public/robots.txt"
run "rm public/images/rails.png"
run "rm app/views/layouts/*.erb"

# remove prototype js
run "rm -f public/javascripts/*"

# Adds the latest jQuery and Rails UJS helpers for jQuery.
say_recipe 'jQuery'

inside "public/javascripts" do
  get "http://github.com/rails/jquery-ujs/raw/master/src/rails.js", "rails.js"
  get "http://code.jquery.com/jquery-1.4.3.min.js",                 "jquery.min.js"
end

application do
  "\n    config.action_view.javascript_expansions[:defaults] = %w(jquery.min rails)\n"
end

gsub_file "config/application.rb", /# JavaScript.*\n/, ""
gsub_file "config/application.rb", /# config\.action_view\.javascript.*\n/, ""

# Set up .gitignore files, for those lucky ones of us using Git
say_wizard "Initializing Git"

git :init

#run "touch tmp/.gitignore log/.gitignore vendor/.gitignore"
#run %{find . -type d -empty | grep -v "vendor" | grep -v ".git" | grep -v "tmp" | xargs -I xxx touch xxx/.gitignore}
append_file '.gitignore', <<-END
.DS_Store
config/database.yml
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

inject_into_file 'app/controllers/application_controller.rb', :after => "protect_from_forgery\n" do 
%q{
  # Catch any Error404 exceptions and trigger a 404 page to render
  rescue_from Error404, :with => :render_404

  private

  # Return a 404 in the HTTP headers and optionally render 404 not found page if the
  # request was for HTML.
  def render_404
    respond_to do |format|
      format.html { render :file => "#{File.join(Rails.root,'public','404.html')}", :status => 404 }
      format.all  { render :nothing => true, :status => 404 }
    end
    true
  end
}
end

# ========
# = Gems =
# ========
say_wizard 'Creating Gemfile'

# Testing-related
with_options :group => :test do |test_env|
  test_env.gem 'factory_girl'
  test_env.gem 'factory_girl_rails'
  test_env.gem 'mocha'
  test_env.gem 'webrat'
  test_env.gem 'cucumber', :version => ">= 0.9.3"
  test_env.gem 'cucumber-rails'
end

after_bundler do
  generate "cucumber:install --webrat"
end

# Pagination
gem 'will_paginate', :version => "~> 3.0.pre2"

# HAML and SASS by default!
gem 'haml'

gem 'capistrano'
gem 'capistrano-ext'

# Development Helper for Nicer Scaffolds
with_options :group => :development do |dev_env|
  dev_env.gem "nifty-generators"
end

# Build layout helpers
after_bundler do
  generate "nifty:layout --haml"
  # Nifty Generators creates a SASS file by default.  Convert that to SCSS.
  in_root {
    run "sass-convert --from sass2 --to scss --recursive public/stylesheets/sass/"
    run "rm public/stylesheets/sass/*.sass"
  }
end

# ===========
# = Plugins =
# ===========

# Exception Handling
plugin 'exception_notification', :git => "git://github.com/rails/exception_notification.git"

initializer 'exception_notification.rb',<<-END
#{app_const_base.to_s}::Application.config.middleware.use ExceptionNotifier,
      :email_prefix => "[#{app_const_base.to_s.upcase} ERROR] ",
      :sender_address => %{"notifier" <notifier@example.com>},
      :exception_recipients => %w{webmaster@singlebrook.com}
END

# ====================
# = Capistrano Setup =
# ====================

create_file 'config/deploy.rb', <<-END
set :stages, %w(staging production)
set :default_stage, "staging"

require 'capistrano/ext/multistage'
require 'bundler/capistrano'

set :application, "#{app_const_base.to_s.downcase}"
set :repository,  "http://git.singlebrook.com/git/#{app_const_base.to_s.downcase}.git"

set :scm, :git
set :scm_username, ""
set :scm_password, ""
set :deploy_via, :remote_cache

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
    run "\#{try_sudo} touch \#{File.join(current_path,'tmp','restart.txt')}"
  end

  desc "Re-link config files"
  task :link_config_files, :roles => :app do
    run "ln -nsf \#{config_path}/database.yml \#{release_path}/config/database.yml"
  end

  after "deploy:update_code", "deploy:link_config_files"

end

END

create_file 'config/deploy/production.rb', <<-END
set :rails_env, "production"
set :deploy_to, ""
END

create_file 'config/deploy/staging.rb', <<-END
set :rails_env, "development"
set :deploy_to, ""
END

create_file 'Capfile',
%q{load 'deploy' if respond_to?(:namespace) # cap2 differentiator
Dir['vendor/plugins/*/recipes/*.rb'].each { |plugin| load(plugin) }

load 'config/deploy'

}

# ==========================
# = Testing-releated Files =
# ==========================
inject_into_file 'test/test_helper.rb', :after => "self.use_transactional_fixtures = true\n" do
%q{# This is the opposite of "assert", but it reads a little nicer.
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
}
end

say_wizard "Running Bundler install. This will take a while."
run 'bundle install'
say_wizard "Running after Bundler callbacks."
@after_blocks.each{|b| b.call}

# Initial Git Commit
say_wizard "Commiting files into Git."
in_root {
  git :add => "."
  git :commit => "-m 'Initial commit of application.'"
}
