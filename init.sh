#!/bin/bash

## initialize mysqld and set to start on boot
service mysqld start
chkconfig --levels 235 mysqld on

## set up workflow id generator user and db
mysql mysql </share/apps/wf-3.1.5/docs/idgen.mysql.sql

## add wf env stuff to bashrc
cat /share/apps/wf-3.1.5/exec_env.bash >>/etc/bashrc

## open port 1127 on nodes for workflow RMI communication?

## set up prolog and epilog scripts for all.q
## *** this should really be added as a 'rocks' command allowing any queue to be configured for use with workflow ***
## eg: rocks set workflow defaut_queue=all.q hi_queue=hi.q ...
## and set corresponding values in server-conf/htc.conf
## sge_def_queue=all.q
## sge_pri_queue=msc.q
qconf -mattr queue prolog '/share/apps/wf-3.1.5/bin/prolog $host $job_owner $job_id $job_name $queue' all.q
qconf -mattr queue epilog '/share/apps/wf-3.1.5/bin/epilog $host $job_owner $job_id $job_name $queue' all.q

## copy apache ergatis.conf into place
cp ergatis.conf /etc/httpd/conf.d/
service httpd restart

## modify sudoers file to support apache starting Workflow pipelines as kerberos authenticated users
grep -v "Defaults    requiretty" /etc/sudoers >/tmp/sudoers
mv /tmp/sudoers /etc/sudoers
echo "ALL     ALL=(ALL,!#0)   NOPASSWD: /share/apps/ergatis/scratch/workflow/scripts/*.sh" >>/etc/sudoers

## setup kerberos services
### need to package up contents of /var/kerberos and /etc/krb5.conf
chkconfig --levels 235 krb5kdc on
chkconfig --levels 235 kadmin on
chkconfig --levels 235 krb524 on
service krb5kdc restart
service kadmin restart
service krb524 restart

