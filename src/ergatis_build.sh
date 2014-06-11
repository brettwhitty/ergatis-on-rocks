#!/bin/bash

LAZY_CWD=`/opt/rocks/bin/perl -e 'use Cwd qw{abs_path}; print abs_path();'`

ERGATIS_GIT_REPO="https://github.com/jorvis/ergatis.git"
ERGATIS_GIT_CLONE="${LAZY_CWD}/ergatis-git"
ERGATIS_INSTALL="${LAZY_CWD}/ergatis-install"

## for cpan2dist builds
CPAN2DIST_TMP=`mktemp -d`

## for RPMs
RPM_DIR="${LAZY_CWD}/RPMs"

## Makefile.PL expects this to be supplied as an environment variable
SAMPLES_BUILD_DIR="./samples"

## make a directory to store new RPMs we build during ergatis build
## if this directory doesn't already exist
if [ ! -d ${RPM_DIR} ]
then
	mkdir ${RPM_DIR}
fi


if [ ! -d ${ERGATIS_INSTALL} ]
then
	mkdir ${ERGATIS_INSTALL}
else
	echo "Install dir already exists!" 1>&2
	#exit 1

	echo "Removing..." 1>&2
	rm -vrf ${ERGATIS_INSTALL}

	mkdir ${ERGATIS_INSTALL}
fi

if [ ! -d ${ERGATIS_GIT_CLONE} ]
then
	GIT_SSL_NO_VERIFY=true /usr/bin/git clone ${ERGATIS_GIT_REPO} ${ERGATIS_GIT_CLONE}
	
	cd ${ERGATIS_GIT_CLONE}
	
#	ln -s ${ERGATIS_GIT_CLONE}/src/perl ${ERGATIS_GIT_CLONE}/install/bin
#	ln -s ${ERGATIS_GIT_CLONE}/lib ${ERGATIS_GIT_CLONE}/install/lib
else
	cd ${ERGATIS_GIT_CLONE}

	GIT_SSL_NO_VERIFY=true git pull ${ERGATIS_GIT_REPO}
	
fi

## copy contents of install dir into root as Makefile.PL seems to expect
cp install/* .

## Makefile.PL expects this symlink
ln -s src/perl bin

## fix hardcoded paths in Makefile.PL	
sed -i -r 's/my \$cbuild_dir\s*=\s*[^;]+;$/my \$cbuild_dir = ".\/src\/c";/' Makefile.PL
sed -i -r 's/my \$sbuild_dir\s*=\s*[^;]+;$/my \$sbuild_dir = ".\/src\/shell";/' Makefile.PL
sed -i -r 's/my \$tbuild_dir\s*=\s*[^;]+;$/my \$tbuild_dir = ".\/templates\/pipelines";/' Makefile.PL
sed -i -r 's/\)\/R/\)\/src\/R/' Makefile.PL

## dry run to pick up any missing modules
MISSING_PERL_MODS=( $(
                      /opt/rocks/bin/perl Makefile.PL \
		      INSTALL_BASE=/dev/null \
 		      | grep "not found" | cut -f 2
) )

for PERL_MOD in "${MISSING_PERL_MODS[@]}"
do
   :
   ## make Rocks RPM for missing Perl mod
   echo "'${PERL_MOD}' is missing -> using cpan2dist to build RPM and install" 1>&2
   
   ## build RPMs in a temp dir
   cd ${CPAN2DIST_TMP}
   
   ## we'll go one layer deep here trying to fulfill unmet dependencies on install
   MOD_DEPS=( $(
	/opt/rocks/bin/cpan2dist --defaults --makefile --install --format CPANPLUS::Dist::Rocks ${PERL_MOD} 2>&1 \
		| grep "${PERL_MOD}" | grep "is needed" |  grep perl\( | cut -f 2 -d "(" | cut -f 1 -d ")"
   ) )

   ## cross your fingers
   for DEP_MOD in "${MOD_DEPS[@]}"
   do
	:
	## try to build and install the missing dependency as well
	echo "'${DEP_MOD}' is a dependency -> using cpan2dist to build RPM and install" 1>&2

	/opt/rocks/bin/cpan2dist --defaults --makefile --install --format CPANPLUS::Dist::Rocks ${DEP_MOD} 
   
   done
	 
done

## copy RPMs that were built during install here
find . -name "*.noarch.rpm" -exec cp -v {} ${RPM_DIR} \;

## if all has gone well we have RPMs for all Perl module dependencies
## and they have been installed also

cd ${ERGATIS_GIT_CLONE}

make clean

/opt/rocks/bin/perl Makefile.PL INSTALL_BASE=${ERGATIS_INSTALL}

make

make install


