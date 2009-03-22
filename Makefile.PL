use inc::Module::Install;

name     'Yggdrasil';
all_from 'lib/Yggdrasil.pm';

build_requires 'Test::More';

install_script 'bin/ydump';
install_script 'bin/yrestore';

WriteAll;
