Gem::Specification.new do |s|
  s.name = 'gestion'
  s.version = '1.9.1312'
  s.date = '2017-10-30'
  s.summary = 'Gestion of a cultural center'
  s.description = 'This program allows you to handle the courses,
  internet and accounting of a small cultural center.'
  s.authors = ['Linus Gasser']
  s.email = 'ineiti.blue'

  s.files         = `if [ -d '.git' ]; then git ls-files -z; fi`.split("\x0")
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['Entities', 'Views', 'Diplomas.src', 'Binaries', 'Files', 'Images', 'Paths', 'po']

  s.homepage =
      'https://github.com/ineiti/Gestion'
  s.license = 'GPL-3.0'

  s.add_dependency 'qooxview', '1.9.1312'
  s.add_dependency 'africompta', '1.9.1312'
  s.add_dependency 'network', '0.4.0'
  s.add_dependency 'helper_classes', '1.9.1312'
  s.add_dependency 'hilink_modem', '0.4.0'
  s.add_dependency 'serial_modem', '0.4.0'
  s.add_dependency 'prawn', '1.0.0'
end
