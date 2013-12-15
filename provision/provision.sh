#!/bin/bash

#!/bin/bash

debrant_version='0.2.1'

## Tunables

# Debian package checklist
apt_package_check_list=(
	curl
	debian-keyring
	deborphan
	dos2unix
	findutils
	gettext
	geoip-bin
	geoip-database
	git
	gnupg2
	gnupg-curl
	gnu-standards
	imagemagick
	kexec-tools
	links
	libaio1
	libdbi-perl
	libnet-daemon-perl
	libmemcache0
	libmemcached10
	libmysqlclient18=5.5.34-rel32.0-591.wheezy
	localepurge
	lynx
  mailutils
	mcrypt
	memcached
	mlocate
	nginx-extras
	ntp
	ntpdate
  nullmailer
	optipng
	percona-playback
	percona-toolkit
	percona-server-client-5.5
	percona-server-common-5.5
	percona-server-server-5.5
	percona-xtrabackup
	php-apc
	php-pear
	php5-cli
	php5-common
	php5-curl
	php5-dev
	php5-fpm
	php5-gd
	php5-geoip
	php5-imagick
	php5-imap
	php5-mcrypt
	php5-memcache
	php5-memcached
	php5-mysql
	php5-sqlite
	php5-xdebug
	php5-xmlrpc
	php5-xsl
  re2c
	rsync
	screen
	unar
	unrar
	unzip
	vim
	wget
	yui-compressor
	zsh
)


## Main script


# running time measure
start_seconds=`date +%s`
# network check
ping_result=`ping -c 2 8.8.8.8 2>&1`
# known hosts
known_hosts=''

# Text color variables
txtred='\e[0;31m'       # red
txtgrn='\e[0;32m'       # green
txtylw='\e[0;33m'       # yellow
txtblu='\e[0;34m'       # blue
txtpur='\e[0;35m'       # purple
txtcyn='\e[0;36m'       # cyan
txtwht='\e[0;37m'       # white
bldred='\e[1;31m'       # red    - Bold
bldgrn='\e[1;32m'       # green
bldylw='\e[1;33m'       # yellow
bldblu='\e[1;34m'       # blue
bldpur='\e[1;35m'       # purple
bldcyn='\e[1;36m'       # cyan
bldwht='\e[1;37m'       # white
txtund=$(tput sgr 0 1)  # Underline
txtbld=$(tput bold)     # Bold
txtrst='\e[0m'          # Text reset
txtdim='\e[2m'
# Feedback indicators
info="\n${bldblu} % ${txtrst}"
list="${bldcyn} * ${txtrst}"
pass="${bldgrn} √ ${txtrst}"
warn="${bldylw} ! ${txtrst}"
dead="${bldred}!!!${txtrst}"


function newstep {
	echo -e "${txtrst}"
	echo -e "${bldblu}###${txtrst} ${bldwht}$1${txtrst}"
	echo -e "${txtrst}"
}


function main_header {
	echo -e "${bldred}
     _ _       _ _        _                              
  __| (_) __ _(_) |_ __ _| |   ___   ___ ___  __ _ _ __  
 / _\` | |/ _\` | | __/ _\` | |  / _ \ / __/ _ \/ _\` | '_ \ 
| (_| | | (_| | | || (_| | | | (_) | (_|  __/ (_| | | | |
 \__,_|_|\__, |_|\__\__,_|_|  \___/ \___\___|\__,_|_| |_|
         |___/                                           
${txtrst}
	Digital Ocean deploy v. ${txtgrn}$debrant_version${txtrst}
	${txtund}https://github.com/swergroup/debrant${txtreset}
	"
}

function do_apt {
	newstep "APT sources"
	if [ -f /etc/apt/sources.list.d/grml.list ]; then
		sudo rm /etc/apt/sources.list.d/grml.list
	fi

	if [ -f /srv/config/sources.list ]; then
	  echo -e "${list} GPG keys setup"
		# percona server (mysql)
		apt-key adv --keyserver keys.gnupg.net --recv-keys 1C4CBDCDCD2EFD2A	2>&1 > /dev/null
		# varnish
		wget -qO- http://repo.varnish-cache.org/debian/GPG-key.txt | apt-key add -

	  echo -e "${list} sources.list"
		unlink /etc/apt/sources.list
		ln -s /srv/config/sources.list /etc/apt/sources.list
	fi

	newstep "System packages"
	for pkg in "${apt_package_check_list[@]}"
	do
		if dpkg -s $pkg 2>&1 | grep -q 'Status: install ok installed';
		then 
			echo -e "${pass} $pkg"
		else
			echo -e "${warn} $pkg"
			apt_package_install_list+=($pkg)
		fi
	done
	if [ ${#apt_package_install_list[@]} = 0 ];
	then 
	  echo -e "${pass} Nothing to do!"
	else
	  echo -e "${list} Installing packages.."
		aptitude purge ~c
		apt-get update --assume-yes
		apt-get install --force-yes --assume-yes ${apt_package_install_list[@]}
		apt-get clean
	fi
}

function do_mysql {
	# MySQL
	#
	# Use debconf-set-selections to specify the default password for the root MySQL
	# account. This runs on every provision, even if MySQL has been installed. If
	# MySQL is already installed, it will not affect anything. 
	echo mysql-server mysql-server/root_password password root | debconf-set-selections
	echo mysql-server mysql-server/root_password_again password root | debconf-set-selections
	echo percona-server-server percona-server-server/root_password password root | debconf-set-selections
	echo percona-server-server percona-server-server/root_password_again password root | debconf-set-selections

	# services
	newstep "Percona Server (MySQL) Configuration"
	if [ ! -f /etc/mysql/my.cnf ]; then
	#	mv /etc/mysql/my.cnf /etc/mysql/my.cnf-backup
	  echo -e "${list} my.cnf setup"
		ln -s /srv/config/my.cnf /etc/mysql/my.cnf
		echo -e "${list} Restart service"
		service mysql restart
		mysql -u root -e "CREATE FUNCTION fnv1a_64 RETURNS INTEGER SONAME 'libfnv1a_udf.so'"
		mysql -u root -e "CREATE FUNCTION fnv_64 RETURNS INTEGER SONAME 'libfnv_udf.so'"
		mysql -u root -e "CREATE FUNCTION murmur_hash RETURNS INTEGER SONAME 'libmurmur_udf.so'"
	fi
	if [ -f /srv/database/init-custom.sql ]
	then
	  # Create the databases (unique to system) that will be imported with
	  # the mysqldump files located in database/backups/
	  echo -e "${list} Custom MySQL setup..."
		mysql -u root < /srv/database/init-custom.sql
	else
	  # Setup MySQL by importing an init file that creates necessary
	  # users and databases that our vagrant setup relies on.
	  echo -e "${list} Default MySQL setup.."
	  mysql -u root < /srv/database/init.sql
	fi
	# Process each mysqldump SQL file in database/backups to import 
	# an initial data set for MySQL.
	/srv/database/import-sql.sh
}

function do_utils {
	newstep "Utilities setup"
	if which composer &>/dev/null;
	then
		echo -e "${list} Updating Composer.."
		composer self-update
	else
		echo -e "${list} Installing Composer.."
		curl -sS https://getcomposer.org/installer | php
		chmod +x composer.phar
		mv composer.phar /usr/local/bin/composer
	fi
	composer --version

	if [ ! -d /srv/www/wp-cli ]
	then
	  echo -e "${list} Cloning wp-cli repository"
		git clone git://github.com/wp-cli/wp-cli.git /srv/www/wp-cli
		cd /srv/www/wp-cli
	  echo -e "${list} Installing wp-cli"
		composer install
	  echo -e "${list} Installing wp-cli community packages"
		composer config repositories.wp-cli composer http://wp-cli.org/package-index/
		for pack in "${wpcli_packages[@]}"
		do
			echo -e "  ${list} $pack"
		  composer require $pack &>/dev/null
		done
	else
	  echo -e "${list} Updating wp-cli"
		cd /srv/www/wp-cli
		composer update
	fi
	echo -e "${list} wp-cli symlink"
	ln -sf /srv/www/wp-cli/bin/wp /usr/local/bin/wp
	wp --info
}

function do_nginx {

	newstep "Nginx configuration"
	if [ ! -f /etc/nginx/nginx-wp-common.conf ]; then
	  cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf-default
		echo -e "${list} /etc/nginx/nginx.conf"
	  ln -sf /srv/config/nginx/nginx.conf /etc/nginx/nginx.conf
		echo -e "${list} /etc/nginx/nginx-wp-common.conf"
	  ln -sf /srv/config/nginx/nginx-wp-common.conf /etc/nginx/nginx-wp-common.conf
		echo -e "${list} /etc/nginx/custom-sites"
	  ln -sf /srv/config/nginx/sites /etc/nginx/custom-sites
	fi
	if [ ! -e /etc/nginx/server.key ]; then
	  echo -e "${list} Generate Nginx server private key..."
	  vvvgenrsa=`openssl genrsa -out /etc/nginx/server.key 2048 2>&1`
	  echo $vvvgenrsa
	fi
	if [ ! -e /etc/nginx/server.csr ]; then
	  echo -e "${list} Generate Certificate Signing Request (CSR)..."
	  openssl req -new -batch -key /etc/nginx/server.key -out /etc/nginx/server.csr
	fi
	if [ ! -e /etc/nginx/server.crt ]; then
	  echo -e "${list} Sign the certificate using the above private key and CSR..."
	  vvvsigncert=`openssl x509 -req -days 365 -in /etc/nginx/server.csr -signkey /etc/nginx/server.key -out /etc/nginx/server.crt 2>&1`
	  echo $vvvsigncert
	fi
}

function do_php5conf {
	newstep "PHP5 configuration"
	echo -e "${list} Disable xdebug"
	php5dismod xdebug
	echo -e "${list} pool.d/www.conf"
	ln -sf /srv/config/php5/www.conf /etc/php5/fpm/pool.d/www.conf
	echo -e "${list} conf.d/php-custom.ini"
	ln -sf /srv/config/php5/php-custom.ini /etc/php5/fpm/conf.d/php-custom.ini
	echo -e "${list} conf.d/xdebug.ini"
	ln -sf /srv/config/php5/xdebug.ini /etc/php5/fpm/conf.d/xdebug.ini
	echo -e "${list} conf.d/apc.ini"
	ln -sf /srv/config/php5/apc.ini /etc/php5/fpm/conf.d/apc.ini
}

function clean_system {
	# cleaning
	newstep "Housekeeping and service restart"
	echo -e "${list} APT cache cleaning"
	apt-get autoclean
	apt-get autoremove
	rm -f /var/cache/apt/archives/*.deb
	echo -e "${list} Restarting services.."
	service memcached restart
	service mysql restart
	service nginx restart
	service php5-fpm restart
}

function main_footer {


	cat <<BRANDING > /etc/motd
______     _                     _   
|  _  \   | |                   | |  
| | | |___| |__  _ __ __ _ _ __ | |_ 
| | | / _ \ '_ \| '__/ _\` | '_ \| __|
| |/ /  __/ |_) | | | (_| | | | | |_ 
|___/ \___|_.__/|_|  \__,_|_| |_|\__|

BRANDING

	echo $debrant_version > /etc/debrant_version

	newstep "Your ${txtred}Debrant${txtreset}${bldwht} is ready!"

	echo -e "${txtwht}Please add these to your /etc/hosts file:${txtreset}\n"
	echo -e "192.168.100.11   debrant.dev${txtreset}"
	echo -e "192.168.100.11   themetest.debrant.dev${txtreset}"
	echo -e "192.168.100.11   network.debrant.dev${txtreset}"

	echo -e "\n${txtwht}Code repository and issue tracking:"
	echo -e "${txtund}https://github.com/swergroup/debrant${txtreset}\n"

	end_seconds=`date +%s`
	echo -e "\n${txtwht}Provisioning complete in `expr $end_seconds - $start_seconds` seconds\n"
}

export DEBIAN_FRONTEND=noninteractive

main_header
do_apt
#do_mysql
#do_utils
#do_nginx
#do_php5conf
#clean_system
#main_footer
