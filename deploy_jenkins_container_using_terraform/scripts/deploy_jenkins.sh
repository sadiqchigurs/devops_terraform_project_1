#!/bin/bash

# Launching a jenkins container
CONTAINER_NAME=jenkins_serever
USERNAME=admin
PASSWORD=admin
sudo mkdir -p /DATA/jenkins
sudo chmod 777 -v -R /DATA

# Launching a jenkins container
sudo docker run -d -e JAVA_OPTS="-Djenkins.install.runSetupWizard=false" -p 8080:8080 -p 50000:50000 --name $CONTAINER_NAME -v /DATA/jenkins:/var/jenkins_home jenkins/jenkins:lts



# Add Admin user
sudo docker exec -i $CONTAINER_NAME bash <<EOF
cat > /usr/share/jenkins/ref/init.groovy.d/changeAdminPwd.groovy <<'EOG'
import jenkins.model.*
import hudson.security.*

def instance = Jenkins.getInstance()
def hudsonRealm = new HudsonPrivateSecurityRealm(false)
hudsonRealm.createAccount("${USERNAME}", "${PASSWORD}")
instance.setSecurityRealm(hudsonRealm)

// Authorization strategy: full access to admin
def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()
EOG
EOF

# Restart Jenkins container to apply changes
sudo docker restart $CONTAINER_NAME