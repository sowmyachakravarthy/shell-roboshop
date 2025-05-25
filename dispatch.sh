#!/bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# check the user has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

dnf install golang -y
VALIDATE $? "Installing golang"

#Creating system User - idempotent concept
id roboshop
if [ $? -ne 0 ]
then
useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>>$LOG_FILE
VALIDATE $? "Creating Roboshop User" 
else
    echo -e "System user roboshop already created so ... $Y SKIPPING $N"
fi


mkdir -p /app #-p is used because if directory is not created it creates one otherwise skip it. 
VALIDATE $? "Creating app directory"

curl -o /tmp/dispatch.zip https://roboshop-artifacts.s3.amazonaws.com/dispatch-v3.zip &>>$LOG_FILE 
VALIDATE $? "Downloading dispatch"

rm -rf /app/*
cd /app 
unzip /tmp/dispatch.zip &>>$LOG_FILE
VALIDATE $? "Unzipping dispatch"

go mod init dispatch
go get 
go build
VALIDATE $? "Installing dependencies"

cp $SCRIPT_DIR/dispatch.service /etc/systemd/system/dispatch.service
VALIDATE $? "Copying dispatch service file"

systemctl daemon-reload
VALIDATE $? "Reloading dispatch"

systemctl enable dispatch 
systemctl start dispatch
VALIDATE $? "Enabling and starting dispatch"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script execution completed successfully, $Y time taken : $TOTAL_TIME $N" | tee -a $LOG_FILE