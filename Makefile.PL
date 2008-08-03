use inc::Module::Install;

name     'Yggdrasil';
all_from 'lib/Yggdrasil.pm';

build_requires 'Test::More';

auto_install;

WriteAll;
