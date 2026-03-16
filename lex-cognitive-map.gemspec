# frozen_string_literal: true

require_relative 'lib/legion/extensions/cognitive_map/version'

Gem::Specification.new do |spec|
  spec.name          = 'lex-cognitive-map'
  spec.version       = Legion::Extensions::CognitiveMap::VERSION
  spec.authors       = ['Esity']
  spec.email         = ['matthewdiverson@gmail.com']

  spec.summary       = 'LEX Cognitive Map'
  spec.description   = "Tolman's cognitive map + O'Keefe/Moser place and grid cell theory for brain-modeled agentic AI"
  spec.homepage      = 'https://github.com/LegionIO/lex-cognitive-map'
  spec.license       = 'MIT'
  spec.required_ruby_version = '>= 3.4'

  spec.metadata['homepage_uri']      = spec.homepage
  spec.metadata['source_code_uri']   = 'https://github.com/LegionIO/lex-cognitive-map'
  spec.metadata['documentation_uri'] = 'https://github.com/LegionIO/lex-cognitive-map'
  spec.metadata['changelog_uri']     = 'https://github.com/LegionIO/lex-cognitive-map'
  spec.metadata['bug_tracker_uri']   = 'https://github.com/LegionIO/lex-cognitive-map/issues'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir.glob('{lib,spec}/**/*') + %w[lex-cognitive-map.gemspec Gemfile]
  end
  spec.require_paths = ['lib']
  spec.add_development_dependency 'legion-gaia'
end
