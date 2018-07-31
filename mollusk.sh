#!/bin/bash

#####################################################################################################
# Mollusk: A shell script for simplifying and automating the following tasks for my Docker projects #
# - Backing up databases                                                                            #
# - Restoring databases from backups that were previously created                                   #
# - Generating SSL certificates by using Let's Encrypt                                              #
# - Renewing SSL certificates                                                                       #
# - Generating basic NGINX configuration files                                                      #
#####################################################################################################

arguments=("$@") # User arguments

help_main(){
  echo "Usage: mollusk.sh [FUNCTION]"
  echo ""
  echo "[FUNCTION]"
  echo "nconf   Generate a basic NGINX config file"
  echo "ssl     Create new SSL certificates"
  echo "renew   Renew SSL certificates"
  echo "newdb   Creates a new MySQL database from an SQL file"
  echo "backup  Backup the database"
  echo "restore Restore the database from most recent backup"
  echo "compose Creates a default template Docker compose file"
  echo ""
  echo "Pass a function name for more information on how to use it"
  echo "Example: mollusk.sh backup"
  echo ""
  exit
}

help_nconf(){
  echo "Usage: mollusk.sh nconf [PARAMETERS] [OPTIONS]"
  echo ""
  echo "[PARAMETERS]"
  echo "-c Container name that contains the service to forward to"
  echo "-s Server name(s); ip is special and will use the instance's public ipv4"
  echo ""
  echo "[OPTIONS]"
  echo "-p Port number (default = 80)"
  echo ""
  echo "Example: mollusk.sh nconf -c sample-app -s ip"
  echo "Example: mollusk.sh nconf -c phpmyadmin -s ip -p 9000"
  echo "Example: mollusk.sh nconf -c samples -s sample-data.com"
  echo "Example: mollusk.sh nconf -c example -s example.com 34.218.241.246"
  echo ""
  exit
}

help_ssl(){
  echo "Usage: mollusk.sh ssl [PARAMETERS] [OPTIONS] [FLAGS]"
  echo ""
  echo "[PARAMETERS]"
  echo "-d  Domain for the SSL certificate, you may optionally specify a port number (default is 80)"
  echo "-se Service name of what you're creating the SSL certificate for"
  echo "-st Stack name that contains the service"
  echo ""
  echo "[OPTIONS]"
  echo "-e Email to use when generating certs"
  echo ""
  echo "[FLAGS]"
  echo "-s Staging mode, generate an SSL cert for testing (default is production)"
  echo ""
  echo "Example: mollusk.sh ssl -d example.com -se example-com -st sample"
  echo "Example: mollusk.sh ssl -d example.com:9001 -se example-com -st sample"
  echo "Example: mollusk.sh ssl -d example.com -se example-com -st sample -s"
  echo "Example: mollusk.sh ssl -d example.com:9001 -se example-com -st sample -e myself@example.com -s"
  echo ""
  exit
}

help_backup(){
  echo "Usage: mollusk.sh backup [PARAMETERS]"
  echo ""
  echo "[PARAMETERS]"
  echo "-u Username for the database"
  echo "-p Password for the database"
  echo "-d Database name"
  echo "-b Bucket name"
  echo ""
  echo "Example: mollusk.sh backup -u root -p fizz -d my_sqldb -b tundra-backups"
  echo ""
  exit
}

help_restore(){
  echo "Usage: mollusk.sh restore [PARAMETERS]"
  echo ""
  echo "[PARAMETERS]"
  echo "-u Username for the database"
  echo "-p Password for the database"
  echo "-d Database name"
  echo "-b Bucket name"
  echo ""
  echo "Example: mollusk.sh restore -u root -p fizz -d my_sqldb -b tundra-backups"
  echo ""
  exit
}

help_new_database(){
  echo "Usage: mollusk.sh newdb [PARAMETERS] [OPTIONS]"
  echo ""
  echo "[PARAMETERS]"
  echo "-f Path to the SQL file that will be used to create the database"
  echo "-p Password to the database"
  echo ""
  echo "[OPTIONS]"
  echo "-u Username to the database. Default is \"root\""
  echo "-n Name of the database. Default is the filename"
  echo "-s Name of MySQL Docker service. Default is \"mysql\""
  echo ""
  echo "Example: mollusk.sh newdb -f my_db.sql -p fizz"
  echo "Example: mollusk.sh newdb -f prod.sql -p fizz -n web_app"
  echo "Example: mollusk.sh newdb -f db/template.sql -p fizz -s dock-sql"
  echo "Example: mollusk.sh newdb -f basic.sql -u admin -p fizz -n web_app -s dock-sql"
  echo ""
  exit
}

options_nconf(){
  if [ ${#arguments[@]} = 0 ]; then
    help_nconf
  fi

  current_param=""
  container_name=""
  server_names=()
  port="80"

  for i in "${arguments[@]}"; do # Go through all user arguments

    # If the argument starts with a dash, then set it as the current parameter
    if [ "${i:0:1}" = "-" ]; then
      current_param="${i}"
    elif [ "${current_param}" = "-c" ]; then
      container_name="${i}"
    elif [ "${current_param}" = "-s" ]; then

      # Special case, get the EC2 instance's public IPv4 address
      if [ "${i}" = "ip" ]; then
        i="$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)"
      fi

      server_names+=("${i}")

    elif [ "${current_param}" = "-p" ]; then
      port="${i}"
    else
      echo "ERROR! Unrecognized parameter: ${current_param}"
    fi
  done

  # Use the container's name as the upstream's name
  # upstream_name="${container_name}"

  # Assign all of the server names
  server_name=""
  for i in "${server_names[@]}"; do
    server_name+=" $i"
  done

  # Now generate the NXINX config file
  echo "upstream ${container_name} {server ${container_name}:80;}"  > "nginx_conf.d/${container_name}".conf
  echo "server {"                                                  >> "nginx_conf.d/${container_name}".conf
  echo "  listen ${port};"                                         >> "nginx_conf.d/${container_name}".conf
  echo "  server_name${server_name};"                              >> "nginx_conf.d/${container_name}".conf
  echo "  location / {proxy_pass http://${container_name};}"       >> "nginx_conf.d/${container_name}".conf
  echo "}"                                                         >> "nginx_conf.d/${container_name}".conf

  restart_nginx
}

options_ssl(){
  if [ "${#arguments[@]}" = 0 ]; then
    help_ssl
  fi

  domain=""
  service_name=""
  stack_name=""
  email="--register-unsafely-without-email"
  staging="false"

  for i in "${arguments[@]}"; do # Go through all user arguments
    # Handle flags first
    if [ "${i}" = "-s" ]; then # Flag: Staging
      staging="true"

    # If the argument starts with a dash, then set it as the current parameter/option
    elif [ "${i:0:1}" = "-" ]; then
      current_param="${i}"

    # Handle parameters and options
    elif [ "${current_param}" = "-d" ]; then # Parameter: Domain
      domain="${i}"
    elif [ "${current_param}" = "-se" ]; then # Parameter: Service name
      service_name="${i}"
    elif [ "${current_param}" = "-st" ]; then # Parameter: Stack name
      stack_name="${i}"
    elif [ "${current_param}" = "-e" ]; then # Option: Email
      email="--email ${i}"

    # Error
    else
      echo "Error: Unrecognized parameter: ${current_param}"
      exit
    fi
  done

  # Check if mandatory parameters have been supplied
  failed=""

  if [ "${domain}" = "" ]; then
    echo "Error: Missing parameter: -d"
    failed="true"
  fi

  if [ "${service_name}" = "" ]; then
    echo "Error: Missing parameter: -se"
    failed="true"
  fi

  if [ "${stack_name}" = "" ]; then
    echo "Error: Missing parameter: -st"
    failed="true"
  fi

  if [ "${failed}" = "true" ]; then
    exit
  fi

  # Get port number if the user supplied it
  IFS=":"
  read -ra temp <<< "${domain}"
  domain_name=${temp[0]}
  port_number=${temp[1]}
  if [ "${port_number}" = "" ]; then
    port_number="80"
  fi

  # Create a new configuration file for NGINX
  generate_conf_part_1 "$domain_name" "$service_name" "$port_number"
  restart_nginx

  if [ "${staging}" = "true" ]; then

    # Staging mode

    docker run -it --rm --name certbot                        \
    -v "${stack_name}"_ssl:/etc/letsencrypt                   \
    -v "${stack_name}"_ssl_challenge:/ssl_challenge           \
    certbot/certbot certonly "${email}" --webroot --agree-tos \
    -w /ssl_challenge --staging -d "${domain_name}"

    echo "COMPLETE: certbot in staging mode"

  else

    # Production mode

    docker run -it --rm --name certbot                        \
    -v "${stack_name}"_ssl:/etc/letsencrypt                   \
    -v "${stack_name}"_ssl_challenge:/ssl_challenge           \
    certbot/certbot certonly "${email}" --webroot --agree-tos \
    -w /ssl_challenge -d "${domain_name}"

    echo "COMPLETE: certbot in production mode"

  fi

  generate_conf_part_2 "${domain_name}"
  restart_nginx
}

options_new_database(){
  if [ "${#arguments[@]}" = 0 ]; then
    help_new_database
  fi

  # echo "-f Path to the SQL file that will be used to create the database"
  # echo "-n Name of the database. If omitted, this will be the filename"
  # echo "-s Name of MySQL Docker service. If omitted, this will default to mysql"

  filename=""
  db_password=""
  db_username="root"
  db_name=""
  service_name="mysql"

  for i in "${arguments[@]}"; do # Go through all user arguments
    # If the argument starts with a dash, then set it as the current parameter/option
    if [ "${i:0:1}" = "-" ]; then
      current_param="${i}"

    # Handle parameters and options
    elif [ "${current_param}" = "-f" ]; then # Parameter: Filename
      filename="${i}"
    elif [ "${current_param}" = "-p" ]; then # Parameter: Database password
      db_password="${i}"
    elif [ "${current_param}" = "-u" ]; then # Option: Database username
      db_username="${i}"
    elif [ "${current_param}" = "-n" ]; then # Option: Database name
      db_name="${i}"
    elif [ "${current_param}" = "-s" ]; then # Option: Service name
      service_name="${i}"

    # Error
    else
      echo "Error: Unrecognized parameter: ${current_param}"
      exit
    fi
  done

  # Check if mandatory parameters have been supplied
  failed=""

  if [ "${filename}" = "" ]; then
    echo "Error: Missing parameter: -f"
    failed="true"
  fi

  if [ "${db_password}" = "" ]; then
    echo "Error: Missing parameter: -p"
    failed="true"
  fi

  if [ "${failed}" = "true" ]; then
    exit
  fi

  # Quit if the user specified a file that doesn't exist
  if [ ! -f ${filename} ]; then
    echo "File not found!"
    return
  fi

  # If the user didn't supply a database name, set it to the default of the filename
  if [ "${db_name}" = "" ]; then
    db_name=$(cut -d'.' -f1 <<< ${filename})
  fi

  # Store the container ID that has the word of service_name in its name; default is "mysql"
  mysql_container=$(docker container ls | grep "${service_name}" | grep -Eo '^[^ ]+')

  # Copy the .sql file into the container
  docker cp "${filename}" "${mysql_container}":/"${filename}"

  # Create the database
  command="mysql -u root -p${db_password} -e 'create database ${db_name}'"
  docker exec "${mysql_container}" bash -c "${command}"
  echo "> ${command}"

  # Import data from the .sql file into the database
  command="mysql -u root -p${db_password} ${db_name} < ${filename}"
  echo "> ${command}"
  docker exec "${mysql_container}" bash -c "${command}"

  # Remove the .sql file from the container
  command="rm /${filename}"
  echo "> ${command}"
  docker exec "${mysql_container}" bash -c "${command}"
}

options_backup_or_restore(){
  if [ ${#arguments[@]} = 0 ]; then
    help_"${1}"
  fi

  db_username=""
  db_password=""
  db_database=""
  bucket_name=""

  for i in "${arguments[@]}"; do # Go through all user arguments
    # If the argument starts with a dash, then set it as the current parameter/option
    if [ "${i:0:1}" = "-" ]; then
      current_param="${i}"

    # Handle parameters and options
    elif [ "${current_param}" = "-u" ]; then # Parameter: Username for the database
      db_username="${i}"
    elif [ "${current_param}" = "-p" ]; then # Parameter: Password for the database
      db_password="${i}"
    elif [ "${current_param}" = "-d" ]; then # Parameter: Database name
      db_database="${i}"
    elif [ "${current_param}" = "-b" ]; then # Parameter: Bucket name
      bucket_name="${i}"

    # Error
    else
      echo "Error: Unrecognized parameter: ${current_param}"
      exit
    fi
  done

  # Check if mandatory parameters have been supplied
  failed=""

  if [ "${db_username}" = "" ]; then
    echo "Error: Missing parameter: -u"
    failed="true"
  fi

  if [ "${db_password}" = "" ]; then
    echo "Error: Missing parameter: -p"
    failed="true"
  fi

  if [ "${db_database}" = "" ]; then
    echo "Error: Missing parameter: -d"
    failed="true"
  fi

  if [ "${bucket_name}" = "" ]; then
    echo "Error: Missing parameter: -b"
    failed="true"
  fi

  if [ "${failed}" = "true" ]; then
    exit
  fi

  execute_"${1}" "${db_username}" "${db_password}" "${db_database}" "${bucket_name}"
}

generate_conf_part_1(){
  domain_name="${1}"
  service_name="${2}"
  port_number="${3}"

  echo "upstream ${domain_name} {
  server ${service_name}:${port_number};
}

server {
  listen 80;
  server_name ${domain_name} www.${domain_name};

  location / {
    return 301 https://${domain_name}\$request_uri;
  }

  location /.well-known/acme-challenge/ {
    alias /ssl_challenge/.well-known/acme-challenge/;
  }
}" > ./nginx_conf.d/"${1}".conf
}

generate_conf_part_2(){
  domain_name="${1}"

  echo "
server {
  listen 443 ssl;
  server_name ${domain_name};

  ssl_certificate     /ssl/live/${domain_name}/fullchain.pem;
  ssl_certificate_key /ssl/live/${domain_name}/privkey.pem;

  ssl_protocols TLSv1 TLSv1.1 TLSv1.2;
  ssl_prefer_server_ciphers on;
  ssl_ciphers \"ssl_ciphers ECDH+AESGCM:DH+AESGCM:ECDH+AES256:DH+AES256:ECDH+AES128:DH+AES:RSA+AESGCM:RSA+AES:!aNULL:!MD5:!DSS\";
  ssl_ecdh_curve secp384r1;
  ssl_session_cache shared:SSL:10m;
  ssl_session_tickets off;
  ssl_stapling on;
  ssl_stapling_verify on;
  resolver 8.8.8.8 8.8.4.4 valid=300s;
  resolver_timeout 5s;
  add_header Strict-Transport-Security \"max-age=63072000; includeSubdomains\";
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;

  ssl_dhparam /dhparam.pem;

  location / {proxy_pass http://${domain_name};}
}

server {
  listen 443 ssl;
  server_name www.${domain_name};

  ssl_certificate     /ssl/live/${domain_name}/fullchain.pem;
  ssl_certificate_key /ssl/live/${domain_name}/privkey.pem;

  rewrite ^/(.*)$ https://${domain_name}/\$1 redirect;
  return 301 https://${domain_name}\$request_uri;
}" >> ./nginx_conf.d/"${domain_name}".conf
}

execute_backup(){
  echo "Backing up the database..."

  db_username="${1}"
  db_password="${2}"
  db_database="${3}"
  bucket_name="${4}"
  current_time=$(date "+%Y-%m-%dT%H-%M-%S")
  db_filename="mysql-backup-${current_time}.sql.gz"

  # Save the container that has the word "mysql" in its name as a variable
  mysql_container=$(docker container ls | grep mysql | grep -Eo '^[^ ]+')

  # Save a configuration file for MySQL
  docker exec "${mysql_container}" bash -c "echo '[client]'                 > config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'host=localhost'          >> config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'user=${db_username}'     >> config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'password=${db_password}' >> config.cnf"

  # Update the system
  echo "> apt-get update"
  docker exec "${mysql_container}" bash -c "apt-get -qq update"

  # Install the Python package manager
  echo "> apt-get install -y python-pip"
  docker exec "${mysql_container}" bash -c "apt-get -qq install -y python-pip"

  # Install the AWS Command-line Interface
  echo "> pip install awscli"
  docker exec "${mysql_container}" bash -c "pip install -q awscli"

  # Create a backup on the container (the mysqldump command will overwrite any existing mysql-backup file)
  echo "> mysqldump --defaults-extra-file=/config.cnf testing | gzip -9 > ${db_filename}"
  docker exec "${mysql_container}" bash -c "mysqldump --defaults-extra-file=/config.cnf testing | gzip -9 > ${db_filename}"

  # Send the backup to my AWS S3 bucket
  echo "> aws s3 cp ${db_filename} s3://${bucket_name}"
  docker exec "${mysql_container}" bash -c "aws s3 cp ${db_filename} s3://${bucket_name}"

  # Remove the backup file on the container
  echo "> ${mysql_container}" bash -c "rm ${db_filename}"
  docker exec "${mysql_container}" bash -c "rm ${db_filename}"
}

execute_restore(){
  echo "Restoring the database..."

  db_username="${1}"
  db_password="${2}"
  db_database="${3}"
  bucket_name="${4}"

  # Save the container that has the word "mysql" in its name as a variable
  mysql_container=$(docker container ls | grep mysql | grep -Eo '^[^ ]+')

  # Save a configuration file for MySQL
  docker exec "${mysql_container}" bash -c "echo '[client]'                 > config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'host=localhost'          >> config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'user=${db_username}'     >> config.cnf"
  docker exec "${mysql_container}" bash -c "echo 'password=${db_password}' >> config.cnf"

  # Update the system
  echo "> apt-get update"
  docker exec "${mysql_container}" bash -c "apt-get -qq update"

  # Install the Python package manager
  echo "> apt-get install -y python-pip"
  docker exec "${mysql_container}" bash -c "apt-get -qq install -y python-pip"

  # Install the AWS Command-line Interface
  echo "> pip install awscli"
  docker exec "${mysql_container}" bash -c "pip install -q awscli"

  db_filename=$(docker exec "${mysql_container}" bash -c "aws s3 ls ${bucket_name} | sort | tail -n 1" | awk '{print $4}')
  echo "> ${db_filename}"

  # Download the backup from S3
  echo "> aws s3 cp s3://leif-mysql-backups/${db_filename} ${db_filename}"
  docker exec "${mysql_container}" bash -c "aws s3 cp s3://leif-mysql-backups/${db_filename} ${db_filename}"

  # Create the database
  echo "> mysql -u ${db_username} -p${db_password} -e 'create database ${db_database}'"
  docker exec "${mysql_container}" bash -c "mysql -u ${db_username} -p${db_password} -e 'create database ${db_database}'"

  # Restore from backup
  echo "> ${command}"
  docker exec "${mysql_container}" bash -c "${command}"

  # Remove the backup file on the container
  echo "> rm ${db_filename}"
  docker exec "${mysql_container}" bash -c "rm ${db_filename}"
}

restart_nginx(){
  # Reload the NGINX config
  docker exec -it "$(docker container ls | grep nginx | grep -Eo '^[^ ]+')" nginx -s reload
}

renew_certificates(){
  docker run -it --rm --name certbot        \
  -v /home/centos/swag/ssl:/etc/letsencrypt \
  certbot/certbot renew
}

compose(){
  if [ ! -f docker-compose.yml ]; then

    echo 'version: "3.6"'                                                                                                >> "docker-compose.yml"
    echo 'services:'                                                                                                     >> "docker-compose.yml"
    echo ''                                                                                                              >> "docker-compose.yml"
    echo '  nginx:'                                                                                                      >> "docker-compose.yml"
    echo '    image: nginx'                                                                                              >> "docker-compose.yml"
    echo '    ports:'                                                                                                    >> "docker-compose.yml"
    echo '      - published: 80'                                                                                         >> "docker-compose.yml"
    echo '        target: 80'                                                                                            >> "docker-compose.yml"
    echo '        mode: host'                                                                                            >> "docker-compose.yml"
    echo '      - published: 443'                                                                                        >> "docker-compose.yml"
    echo '        target: 443'                                                                                           >> "docker-compose.yml"
    echo '        mode: host'                                                                                            >> "docker-compose.yml"
    echo '      - published: 9000 # Temporary for phpmyadmin; recommended to remove for a URL'                           >> "docker-compose.yml"
    echo '        target: 9000    # Temporary for phpmyadmin; recommended to remove for a URL'                           >> "docker-compose.yml"
    echo '        mode: host'                                                                                            >> "docker-compose.yml"
    echo '    volumes:'                                                                                                  >> "docker-compose.yml"
    echo '      - ./single_files/dhparam.pem:/dhparam.pem         # Custom DH parameters; recommended to change'         >> "docker-compose.yml"
    echo '      - ./single_files/nginx.conf:/etc/nginx/nginx.conf # Custom NGINX config file'                            >> "docker-compose.yml"
    echo '      - ./nginx_conf.d:/etc/nginx/conf.d'                                                                      >> "docker-compose.yml"
    echo '      - ssl_challenge:/ssl_challenge'                                                                          >> "docker-compose.yml"
    echo '      - ssl:/ssl'                                                                                              >> "docker-compose.yml"
    echo ''                                                                                                              >> "docker-compose.yml"
    echo '  mysql:'                                                                                                      >> "docker-compose.yml"
    echo '    image: mysql'                                                                                              >> "docker-compose.yml"
    echo '    volumes:'                                                                                                  >> "docker-compose.yml"
    echo '      - sql_storage:/var/lib/mysql'                                                                            >> "docker-compose.yml"
    echo '    environment:'                                                                                              >> "docker-compose.yml"
    echo '      MYSQL_ROOT_PASSWORD: "fizz"'                                                                             >> "docker-compose.yml"
    echo '    entrypoint: ["/entrypoint.sh", "--default-authentication-plugin=mysql_native_password"]'                   >> "docker-compose.yml"
    echo ''                                                                                                              >> "docker-compose.yml"
    echo '  phpmyadmin:'                                                                                                 >> "docker-compose.yml"
    echo '    image: phpmyadmin/phpmyadmin'                                                                              >> "docker-compose.yml"
    echo '    volumes:'                                                                                                  >> "docker-compose.yml"
    echo '      - ./single_files/config.inc.php:/etc/phpmyadmin/config.inc.php # Custom phpMyAdmin config file'          >> "docker-compose.yml"
    echo '      - ./single_files/header.twig:/www/templates/login/header.twig  # Mod to hide the "https mismatch" error' >> "docker-compose.yml"
    echo '      - ./single_files/index.php:/www/index.php                      # Mod to hide the SSL status'             >> "docker-compose.yml"
    echo '    environment:'                                                                                              >> "docker-compose.yml"
    echo '      PMA_HOST: "mysql"'                                                                                       >> "docker-compose.yml"
    echo '      PMA_PORT: "3306"'                                                                                        >> "docker-compose.yml"
    echo '    depends_on:'                                                                                               >> "docker-compose.yml"
    echo '      - mysql'                                                                                                 >> "docker-compose.yml"
    echo ''                                                                                                              >> "docker-compose.yml"
    echo '  sample-app:'                                                                                                 >> "docker-compose.yml"
    echo '    image: sample-app'                                                                                         >> "docker-compose.yml"
    echo '    volumes:'                                                                                                  >> "docker-compose.yml"
    echo '      - ./logs:/usr/src/app/log'                                                                               >> "docker-compose.yml"
    echo '    depends_on:'                                                                                               >> "docker-compose.yml"
    echo '      - mysql'                                                                                                 >> "docker-compose.yml"
    echo ''                                                                                                              >> "docker-compose.yml"
    echo 'volumes:'                                                                                                      >> "docker-compose.yml"
    echo '  sql_storage:'                                                                                                >> "docker-compose.yml"
    echo '  ssl_challenge:'                                                                                              >> "docker-compose.yml"
    echo '  ssl:'                                                                                                        >> "docker-compose.yml"

  else

    echo "docker-compose.yml already exists"

  fi

  if [ ! -d logs ]; then
    mkdir logs
  fi

  if [ ! -d nginx_conf.d ]; then
    mkdir nginx_conf.d
  fi
}

main(){

  function="${arguments[0]}"
  arguments=("${arguments[@]:1}") # Remove the function (pop from font)

  if [ "${function}" = "nconf" ]; then

    options_nconf

  elif [ "${function}" = "ssl" ]; then

    options_ssl

  elif [ "${function}" = "renew" ]; then

    renew_certificates

  elif [ "${function}" = "newdb" ]; then

    options_new_database

  elif [ "${function}" = "backup" ]; then

    options_backup_or_restore "backup"

  elif [ "${function}" = "restore" ]; then

    options_backup_or_restore "restore"

  elif [ "${function}" = "compose" ]; then

    compose

  else
    help_main
  fi
}

main

echo "=================================================="
echo "====================== DONE ======================"
echo "=================================================="
