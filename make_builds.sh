#!/bin/sh
# This script helps to track build troubles and make portable versions

DIR=/tmp/CPU-X
JOBS=-j2


#########################################################
#			FUNCTIONS			#
#########################################################

make_build() {
	while ! $(ssh -q $1 exit); do
		sleep 1
	done

	ssh $1 << EOF

err() {
	echo -e "\n\t\033[1;41m*** A build failed for $1 ***\033[0m\n\n"
	sleep 5
}

[[ ! -d $DIR ]] && git clone https://github.com/X0rg/CPU-X $DIR
mkdir -pv $DIR/{,e}build{1,2,3,4,5,6,7}

cd $DIR/build1 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr .. && make $JOBS || err
cd $DIR/build2 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_GTK=0 .. && make $JOBS || err
cd $DIR/build3 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_GTK=1 -DWITH_NCURSES=0 .. && make $JOBS || err
cd $DIR/build4 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_NCURSES=1 -DWITH_LIBCPUID=0 .. && make $JOBS || err
cd $DIR/build5 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBCPUID=1 -DWITH_LIBDMI=0 .. && make $JOBS || err
cd $DIR/build6 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBDMI=1 -DWITH_LIBPCI=0 .. && make $JOBS || err
cd $DIR/build7 && cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_INSTALL_PREFIX=/usr -DWITH_LIBPCI=1 -DWITH_LIBSYSTEM=0 .. && make $JOBS || err

cd $DIR/ebuild1 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 .. && make $JOBS || err
cd $DIR/ebuild2 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_GTK=0 .. && make $JOBS || err
cd $DIR/ebuild3 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_GTK=1 -DWITH_NCURSES=0 .. && make $JOBS || err
cd $DIR/ebuild4 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_NCURSES=1 -DWITH_LIBCPUID=0 .. && make $JOBS || err
cd $DIR/ebuild5 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_LIBCPUID=1 -DWITH_LIBDMI=0 .. && make $JOBS || err
cd $DIR/ebuild6 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_LIBDMI=1 -DWITH_LIBPCI=0 .. && make $JOBS || err
cd $DIR/ebuild7 && cmake -DCMAKE_BUILD_TYPE=Debug -EMBED=1 -DWITH_LIBPCI=1 -DWITH_LIBSYSTEM=0 .. && make $JOBS || err

poweroff || sudo poweroff
EOF
}

make_release() {
	while ! $(ssh -q $1 exit); do
		sleep 1
	done

	ssh $1 << EOF

[[ ! -d $DIR ]] && git clone https://github.com/X0rg/CPU-X $DIR
mkdir -pv $DIR/{,g}n_build
cd $DIR && VER=\$(git tag | tail -n1)

cd $DIR/gn_build && cmake -DCMAKE_BUILD_TYPE=Release -DEMBED=1 .. && make $JOBS
cd $DIR/n_build  && cmake -DCMAKE_BUILD_TYPE=Release -DEMBED=1 -DWITH_GTK=0 .. && make $JOBS

[[ $1 == "Arch32" ]] && ARCH="linux32" || ARCH="linux64"
cp -v $DIR/gn_build/accomplished/bin/cpu-x "/mnt/Echange/CPU-X_\${VER}_portable.\$ARCH"
cp -v $DIR/n_build/accomplished/bin/cpu-x  "/mnt/Echange/CPU-X_\${VER}_portable_noGTK.\$ARCH"
EOF
}

help() {
	echo -e "Usage: $0 OPTION"
	echo -e "Options:"
	echo -e "\t-b, --build\tStart multiples builds to find build troubles"
	echo -e "\t-r, --release\tBuild portable versions when a new version is tagged"
	echo -e "\t-h, --help\tDisplay this help and exit"
}


#########################################################
#			MAIN				#
#########################################################

if [[ $# < 1 ]]; then
	help
	exit 1
else
	case "$1" in
		-b|--build)	choice="build"; exit 0;;
		-r|--release)	choice="release"; exit 1;;
		-h|--help)	help; exit 0;;
		- |--)		help; exit 1;;
		*)		help; exit 1;;
	esac
fi

if [[ $choice == "build" ]]; then
	# Start VMs
	VBoxManage list runningvms | grep -q "Arch Linux i686"   || (echo "Start 32-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux i686" &)
	VBoxManage list runningvms | grep -q "GhostBSD" || (echo "Start 32-bit BSD VM" ; VBoxHeadless --startvm "GhostBSD" &)
	VBoxManage list runningvms | grep -q "OS X" || (echo "Start 64-bit OS X VM" ; VBoxHeadless --startvm "OS X" &)
	sleep 5

	# Start build
	make_build Arch32
	read
	make_build BSD
	read
	make_build OSX

elif [[ $choice == "release" ]]; then
	# Start VMs
	VBoxManage list runningvms | grep -q "Arch Linux i686"   || (echo "Start 32-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux i686" &)
	VBoxManage list runningvms | grep -q "Arch Linux x86_64" || (echo "Start 64-bit Linux VM" ; VBoxHeadless --startvm "Arch Linux x86_64" &)
	VBoxManage list runningvms | grep -q "GhostBSD" || (echo "Start 32-bit BSD VM" ; VBoxHeadless --startvm "GhostBSD" &)
	sleep 5

	# Start build
	make_release Arch32
	make_release Arch64
	make_release BSD
	sshfs BSD:/tmp/CPU-X/ ~/.VirtualBox/Echange/SSHFS

	# Stop Linux VMs
	ssh Arch32 sudo poweroff
	ssh Arch64 sudo poweroff

	# Get BSD ELF
	cd ~/.VirtualBox/Echange/SSHFS
	VER=$(git tag | tail -n1)
	cd ..
	cp -v SSHFS/gn_build/accomplished/bin/cpu-x "./CPU-X_${VER}_portable.bsd32"
	cp -v SSHFS/n_build/accomplished/bin/cpu-x  "./CPU-X_${VER}_portable_noGTK.bsd32"
	fusermount -u SSHFS
	ssh BSD poweroff

	# Make tarball
	tar -zcvf CPU-X_${VER}_portable.tar.gz CPU-X_${VER}_portable.*
	tar -zcvf CPU-X_${VER}_portable_noGTK.tar.gz CPU-X_${VER}_portable_noGTK.*
else
	echo "Bad option."
fi
