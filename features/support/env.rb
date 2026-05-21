require "aruba/cucumber"

Before("@known_bug") { pending("This scenario fails because of a known bug") }

Before do |scenario|
  dir_name = "scenario-#{rand(1_000_000)}"
  create_directory(dir_name)
  cd(dir_name)
end

Before { @aruba_timeout_seconds = 60 }

if RUBY_PLATFORM == "java" && ENV["TRAVIS"]
  Aruba.configure do |config|
    config.before_cmd { set_env("JAVA_OPTS", "#{ENV["JAVA_OPTS"]} -d64") }
  end
end
