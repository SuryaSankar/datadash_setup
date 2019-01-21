#!/bin/bash
set -x #echo on

die() {
    printf '%s\n' "$1" >&2
    exit 1
}


while :; do
    case $1 in
        -h|-\?|--help)
            show_help    # Display a usage synopsis.
            exit
            ;;
        --username=?*)
            username=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --username=)         # Handle the case of an empty --file=
            die 'ERROR: "--username" requires a non-empty option argument.'
            ;;
        --reponame=?*)
            reponame=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --reponame=)         # Handle the case of an empty --file=
            die 'ERROR: "--reponame" requires a non-empty option argument.'
            ;;
        --blogdomain=?*)
            blogdomain=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --blogdomain=)         # Handle the case of an empty --file=
            die 'ERROR: "--blogdomain" requires a non-empty option argument.'
            ;;
        --jupyterhubdomain=?*)
            jupyterhubdomain=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --jupyterhubdomain=)         # Handle the case of an empty --file=
            die 'ERROR: "--jupyterhubdomain" requires a non-empty option argument.'
            ;;
        --use_github_auth)
			use_github_auth=true
            ;;
        --github_client_id=?*)
            github_client_id=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --github_client_id=)         # Handle the case of an empty --file=
            die 'ERROR: "--github_client_id" requires a non-empty option argument.'
            ;;
        --github_client_secret=?*)
            github_client_secret=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --github_client_secret=)         # Handle the case of an empty --file=
            die 'ERROR: "--github_client_secret" requires a non-empty option argument.'
            ;;
        --github_email=?*)
            github_email=${1#*=} # Delete everything up to "=" and assign the remainder.
            ;;
        --github_email=)         # Handle the case of an empty --file=
            die 'ERROR: "--github_email" requires a non-empty option argument.'
            ;;
        --)              # End of all options.
            shift
            break
            ;;
        -?*)
            printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
            ;;
        *)               # Default case: No more options, so break out of the loop.
            break
    esac

    shift
done


sudo apt-get update
# echo "Enter the user name for the administrator. This should be the same as the github user you are going to use"
# read username
sudo adduser $username
sudo usermod -aG sudo $username
# if [ ! -f /opt/anaconda3/bin/conda ]; then
# 	wget https://repo.continuum.io/archive/Anaconda3-2018.12-Linux-x86_64.sh
# 	sudo bash Anaconda3-2018.12-Linux-x86_64.sh
# 	sudo rm Anaconda3-2018.12-Linux-x86_64.sh
# fi

sudo apt-get -y install python3-pip
sudo apt-get -y install npm nodejs
sudo apt-get install python3-dev libmysqlclient-dev
sudo npm install -g configurable-http-proxy
sudo pip3 install --upgrade setuptools six
sudo pip3 install wheel

sudo pip3 install --upgrade jupyter jupyterhub jupyterlab oauthenticator Nikola[extras]
sudo pip3 install --upgrade numpy scipy matplotlib pandas sympy nose
sudo pip3 install --upgrade Jinja2 packaging pillow python-dateutil PyYAML
sudo pip3 install --upgrade sqlalchemy tornado bokeh
sudo pip3 install --upgrade mysqlclient
sudo pip3 install --upgrade voila
# sudo pip3 install --upgrade jupyter
# sudo pip3 install --upgrade jupyterhub
# # sudo pip3 install --upgrade notebook
# sudo pip3 install --upgrade jupyterlab
# sudo pip3 install --upgrade oauthenticator
# sudo pip3 install --upgrade Nikola[extras]

jupyter labextension install @jupyterlab/git
pip3 install jupyterlab-git
jupyter serverextension enable --py --system jupyterlab_git

jupyter labextension install @jupyterlab/hub-extension

# echo Enter the name that you want to give your data dashboard folder
# read reponame


sudo apt-get install nginx

# echo Enter the fully qualified domain name to use for the data blog
# read blogdomain


openssl req -x509 -nodes -newkey rsa:4096 -keyout ${blogdomain}.key -out ${blogdomain}_cert.pem -days 365 -subj '/CN=${blogdomain}'
mkdir -p /etc/ssl/private/${blogdomain}
mv ${blogdomain}_cert.pem ${blogdomain}.key /etc/ssl/private/${blogdomain}/

cat <<EOM > /etc/nginx/sites-available/${blogdomain}.conf
server {
    listen 80;
    listen 443 ssl;
    ssl on;
    ssl_certificate /etc/ssl/private/${blogdomain}/${blogdomain}_cert.pem;
    ssl_certificate_key /etc/ssl/private/${blogdomain}/${blogdomain}.key;
    server_name ${blogdomain};
    root /home/$username/$reponame/output;
}
EOM
sudo ln -s /etc/nginx/sites-available/${blogdomain}.conf /etc/nginx/sites-enabled/

# echo Enter the fully qualified domain name to use for the jupyterhub dashboard
# read jupyterhubdomain

openssl req -x509 -nodes -newkey rsa:4096 -keyout ${jupyterhubdomain}.key -out ${jupyterhubdomain}_cert.pem -days 365 -subj '/CN=${jupyterhubdomain}'
mkdir -p /etc/ssl/private/${jupyterhubdomain}
mv ${jupyterhubdomain}_cert.pem ${jupyterhubdomain}.key /etc/ssl/private/${jupyterhubdomain}/

cat <<EOM > /etc/nginx/sites-available/${jupyterhubdomain}.conf
server {
    listen 80;
    listen 443 ssl;
    ssl on;
    ssl_certificate /etc/ssl/private/${jupyterhubdomain}/${jupyterhubdomain}_cert.pem;
    ssl_certificate_key /etc/ssl/private/${jupyterhubdomain}/${jupyterhubdomain}.key;
    server_name ${jupyterhubdomain};

    location / {
        proxy_pass https://127.0.0.1:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;        
    }
}
EOM
sudo ln -s /etc/nginx/sites-available/${jupyterhubdomain}.conf /etc/nginx/sites-enabled/

# conda_bin=`whereis conda | sed  's/conda: //g'| sed  's/\/conda//g'`

cat <<EOM > /lib/systemd/system/jupyterhub.service
[Unit]
Description=Jupyterhub

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/usr/local/bin/jupyterhub -f /home/$username/$reponame/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOM

sudo ln -s /lib/systemd/system/jupyterhub.service /etc/systemd/system/jupyterhub.service


cd /home/$username
nikola init $reponame

cd $reponame

nikola build

# echo Enter the github oauth client_id
# read github_client_id
# echo Enter the github oauth client_secret
# read github_client_secret
sudo -H -u $username cat <<EOM > jupyterhub_config.py
c.JupyterHub.admin_users = {'$username'}
c.JupyterHub.authenticator_class = 'oauthenticator.GitHubOAuthenticator'
c.GitHubOAuthenticator.oauth_callback_url = 'https://${jupyterhubdomain}/hub/oauth_callback'
c.GitHubOAuthenticator.client_id = '${github_client_id}'
c.GitHubOAuthenticator.client_secret = '${github_client_secret}'
c.JupyterHub.proxy_cmd = ['/usr/local/bin/configurable-http-proxy']
c.JupyterHub.ssl_cert = '/etc/ssl/private/${jupyterhubdomain}/${jupyterhubdomain}_cert.pem'
c.JupyterHub.ssl_key = '/etc/ssl/private/${jupyterhubdomain}/${jupyterhubdomain}.key'
c.Spawner.notebook_dir = '~/$reponame'
c.Authenticator.whitelist = {'$username'}
c.LocalAuthenticator.create_system_users = True
c.JupyterHub.ip = '127.0.0.1'
c.Spawner.default_url = '/lab'
c.JupyterHub.log_level = 'DEBUG'
c.Spawner.debug = True
c.LocalProcessSpawner.debug = True
EOM
cat <<EOM > .gitignore
*.pid
*.sqlite
jupyterhub_cookie_secret
.ipynb_checkpoints/
__pycache__/
cache/
.doit.db
EOM
cd -

sudo chown -R $username:$username /home/$username/$reponame


sudo systemctl daemon-reload
sudo systemctl start
sudo systemctl enable jupyterhub.service
sudo service nginx restart

cd /home/$username
mkdir -p /home/$username/.ssh

# echo Enter the email associated with your github account
# read github_email
sudo -H -u $username ssh-keygen -t rsa -b 4096 -C $github_email
sudo -H -u $username ssh-add ~/.ssh/id_rsa

sshkey=`sudo -H -u $username cat /home/$username/.ssh/id_rsa.pub`
curl -u $username https://api.github.com/user/keys -d "{\"title\":\"${blogdomain}\", \"key\":\"$sshkey\"}"

cd /home/$username/$reponame
sudo -H -u $username git init
sudo -H -u $username git config user.email $github_email
sudo -H -u $username git add -A
sudo -H -u $username git commit -am "Finished initial auto setup"


curl -u $username https://api.github.com/user/repos -d "{\"name\":\"$reponame\"}"

sudo -H -u $username git remote add origin "https://github.com/$username/$reponame.git"
sudo -H -u $username git push -u origin master

echo "SUCCESS"



