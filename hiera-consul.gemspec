require 'rubygems'
require 'rubygems/package_task'

spec = Gem::Specification.new do |gem|
    gem.name = "hiera-consul"
    gem.version = "0.0.2"
    gem.license = "Apache-2.0"
    gem.summary = "Module for using consul as a hiera backend"
    gem.email = "jonathan.sokolowski@gmail.com"
    gem.author = "Jonathan Sokolowski"
    gem.homepage = "http://github.com/jsok/hiera-consul"
    gem.description = "Hiera backend for looking up KV data stored in Vault"
    gem.require_path = "lib"
    gem.files = FileList["lib/**/*"].to_a
    gem.add_dependency('json')
end
