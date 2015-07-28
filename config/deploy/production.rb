role :app, %w{crutter}
role :web, %w{crutter}
role :db,  %w{crutter}

set :stage, :production
set :rails_env, :production

set :deploy_to, '/home/ec2-user/crutter'

set :default_env, {
  rbenv_root: "/home/ec2-user/.rbenv",
  path: "/home/ec2-user/.rbenv/shims:/home/ec2-user/.rbenv/bin:$PATH",
}
