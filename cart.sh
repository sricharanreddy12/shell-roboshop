#! /bin/bash

START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD #$PWD in shell is special variable for checking the present working directory

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# check the cart has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# validate functions takes input as $? exit status, what command they tried to install
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
VALIDATE $? "Disabling default node Js Version "

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling the nodejs:20"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing Nodejs"

#Script needs to be idempotent--irrespective times of  running the same script, execution should not unchange
id roboshop &>>$LOG_FILE
if [ $? -ne 0 ]
then
   useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop
   VALIDATE $? "Creating roboshop system user"
else
    echo -e "System cart already created-- $Y Skipping $N"
fi    
 
mkdir -p /app 
VALIDATE $? "Creating app directory"

curl -o /tmp/cart.zip https://roboshop-artifacts.s3.amazonaws.com/cart-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading cart"

# removing content inside app directory for exceuting the script idempotent 
rm -rf /app/* 
cd /app 
unzip /tmp/cart.zip &>>$LOG_FILE
VALIDATE $? "Unzipping cart"

npm install &>>$LOG_FILE
VALIDATE $? "Installing Nodejs dependencies"

cp $SCRIPT_DIR/cart.service /etc/systemd/system/cart.service
VALIDATE $? "copying cart service"

systemctl daemon-reload &>>$LOG_FILE
systemctl enable cart  &>>$LOG_FILE
systemctl start cart &>>$LOG_FILE
VALIDATE $? "Starting Cart"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE