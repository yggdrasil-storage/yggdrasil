use inc::Module::Install;

name     'Yggdrasil';
all_from 'lib/Yggdrasil.pm';

test_requires 'Test::More';
test_requires 'DBD::SQLite';

install_script 'bin/ydump';
install_script 'bin/yrestore';

WriteAll;
