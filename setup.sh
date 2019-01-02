#!/bin/bash
set -x #echo on

echo "Enter the user name for the administrator. This should be the same as the github user you are going to use"
read adminuser
adduser $adminuser
usermod -aG sudo $adminuser
cd /opt
wget https://repo.continuum.io/archive/Anaconda3-2018.12-Linux-x86_64.sh
bash Anaconda3-2018.12-Linux-x86_64.sh
rm Anaconda3-2018.12-Linux-x86_64.sh
cd -

sudo apt-get -y install python3-pip
sudo apt-get -y install npm nodejs
sudo npm install -g configurable-http-proxy
sudo pip3 install --upgrade setuptools
sudo pip3 install --upgrade jupyterhub
sudo pip3 install --upgrade notebook
sudo pip3 install --upgrade oauthenticator
sudo pip3 install --upgrade Nikola[extras]
sudo pip3 install -r requirements.txt

cd /home/$adminuser
echo Enter the name that you want to give your data dashboard folder
read reponame


sudo apt-get install nginx

echo Enter the fully qualified domain name to use for the data blog
read blogdomain
echo Enter the fully qualified domain name to use for the jupyterhub dashboard
read jupyterhubdomain

openssl req -x509 -nodes -newkey rsa:4096 -keyout $blogdomain.key -out $blogdomain_cert.pem -days 365
mkdir -p /etc/ssl/private/$blogdomain
mv $blogdomain_cert.pem $blogdomain.key /etc/ssl/private/$blogdomain/

openssl req -x509 -nodes -newkey rsa:4096 -keyout $jupyterhubdomain.key -out $jupyterhubdomain_cert.pem -days 365
mkdir -p /etc/ssl/private/$jupyterhubdomain
mv $jupyterhubdomain_cert.pem $jupyterhubdomain.key /etc/ssl/private/$jupyterhubdomain/

cat <<EOM > /etc/nginx/sites-available/$blogdomain.conf
server {
    listen 80;
    listen 443 ssl;
    ssl on;
    ssl_certificate /etc/ssl/private/$blogdomain/$blogdomain_cert.pem;
    ssl_certificate_key /etc/ssl/private/$blogdomain/$blogdomain.key;
    server_name $blogdomain;
    root /home/$adminuser/$reponame/output;
}
EOM
sudo ln -s /etc/nginx/sites-available/$blogdomain.conf /etc/nginx/sites-enabled/


cat <<EOM > /etc/nginx/sites-available/$jupyterhubdomain.conf
server {
    listen 80;
    listen 443 ssl;
    ssl on;
    ssl_certificate /etc/ssl/private/$jupyterhubdomain/$jupyterhubdomain_cert.pem;
    ssl_certificate_key /etc/ssl/private/$jupyterhubdomain/$jupyterhubdomain.key;
    server_name $jupyterhubdomain;

    location / {
        proxy_pass http://localhost:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;        
    }
}
EOM
sudo ln -s /etc/nginx/sites-available/$jupyterhubdomain.conf /etc/nginx/sites-enabled/

cat <<EOM > /lib/systemd/system/jupyterhub.service
[Unit]
Description=Jupyterhub

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/opt/anaconda3/bin"
ExecStart=/usr/local/bin/jupyterhub -f /home/$adminuser/$reponame/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOM

sudo ln -s /lib/systemd/system/jupyterhub.service /etc/systemd/system/jupyterhub.service

nikola init $reponame

cd $reponame
jupyterhub --generate-config

echo Enter the github oauth client_id
read github_client_id
echo Enter the github oauth client_secret
read github_client_secret
cat <<EOM >> jupyterhub_config.py
c.JupyterHub.admin_users = {'$adminuser'}
c.JupyterHub.authenticator_class = 'oauthenticator.GitHubOAuthenticator'
c.GitHubOAuthenticator.oauth_callback_url = 'https://$jupyterhubdomain/hub/oauth_callback'
c.GitHubOAuthenticator.client_id = '$github_client_id'
c.GitHubOAuthenticator.client_secret = '$github_client_secret'
c.JupyterHub.proxy_cmd = ['/usr/local/bin/configurable-http-proxy']
c.JupyterHub.ssl_cert = '/etc/ssl/private/$jupyterhubdomain/$jupyterhubdomain_cert.pem'
c.JupyterHub.ssl_key = '/etc/ssl/private/$jupyterhubdomain/$jupyterhubdomain.key'
c.Spawner.notebook_dir = '~/$reponame'
c.Authenticator.whitelist = {'$adminuser'}
c.LocalAuthenticator.create_system_users = True
EOM
cat <<EOM > .gitignore
*.pid
*.sqlite
jupyterhub_cookie_secret
EOM
cd -


sudo systemctl daemon-reload
sudo systemctl start
sudo systemctl enable jupyterhub.service
sudo service nginx restart


su $adminuser
cd /home/$adminuser
mkdir -p /home/$adminuser/.ssh

echo Enter the email associated with your github account
read adminuser_email
ssh-keygen -t rsa -b 4096 -C $adminuser_email
ssh-add ~/.ssh/id_rsa

echo "Copy the following ssh key to your github account (Refer https://help.github.com/articles/adding-a-new-ssh-key-to-your-github-account/ )"
cat ~/.ssh/id_rsa.pub
echo "Press Enter if you have added it to your github account"
read enter

cd /home/$adminuser/$reponame
git init
git config user.email $adminuser_email
git add -A
git commit -am "Finished initial auto setup"


# curl -u $adminuser https://api.github.com/user/repos -d "{\"name\":\"$reponame\"}"

# git remote add origin "https://github.com/$adminuser/$reponame.git"
# git push -u origin master

echo "SUCCESS"



