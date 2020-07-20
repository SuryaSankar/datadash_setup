jupyter labextension install @jupyterlab/git
jupyter serverextension enable --py --system jupyterlab_git
jupyter labextension install @jupyterlab/hub-extension

cat <<EOM > /lib/systemd/system/jupyterhub.service
[Unit]
Description=Jupyterhub

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin"
ExecStart=/usr/local/bin/jupyterhub -f /home/$1/sites/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOM

sudo ln -s /lib/systemd/system/jupyterhub.service /etc/systemd/system/jupyterhub.service

cd /home/$1/sites

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

cd -
