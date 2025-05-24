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

dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling default nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling current nodejs"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing nodejs"

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

curl -L -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading catalogue"

rm -rf /app/*
cd /app 
unzip /tmp/cart.zip &>>$LOG_FILE
VALIDATE $? "Unzipping catalogue"

npm install &>>$LOG_FILE
VALIDATE $? "Installing Dependencies"


cp $SCRIPT_DIR/cart.service /etc/systemd/system/cart.service &>>$LOG_FILE
VALIDATE $? "COpying cart service"

systemctl daemon-reload
systemctl enable user 
systemctl start user
VALIDATE $? "Reloading, enabling and restarting the services"   

END_TIME=$(date +%s) 
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script execution completed successfully, $Y time taken : $TOTAL_TIME $N" | tee -a $LOG_FILE