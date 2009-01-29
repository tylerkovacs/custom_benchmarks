# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{custom_benchmarks}
  s.version = "0.4.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["tylerkovacs"]
  s.date = %q{2009-01-28}
  s.description = %q{Custom Benchmarks allow you to easily log your own information to the rails log at the end of each request.}
  s.email = %q{tyler.kovacs@gmail.com}
  s.files = ["VERSION.yml", "lib/custom_benchmarks.rb", "lib/adapters", "lib/adapters/memcache-client.rb"]
  s.has_rdoc = true
  s.homepage = %q{http://github.com/tylerkovacs/custom_benchmarks}
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.1}
  s.summary = %q{custom_benchmarks}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 2

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
    else
    end
  else
  end
end
