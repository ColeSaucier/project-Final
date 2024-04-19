# Project Details

This project is a math application that caters to students, teachers, administrators, and parents. Teachers can assign questions to students, students can answer questions and check their responses, parents can monitor their student's progress, and administrators can add new content to the site, such as new students, classrooms, questions, teachers, or parents. Our application also provides feedback on student performance through individual reports and a leaderboard. It aims to offer comprehensive information to parents and teachers, enabling them to better support their students' development.

# MySQL + Flask Boilerplate Project
This repo contains a boilerplate setup for spinning up 3 Docker containers: 
1. A MySQL 8 container for obvious reasons
1. A Python Flask container to implement a REST API
1. A Local AppSmith Server

## How to setup and start the containers
**Important** - you need Docker Desktop installed

1. Clone this repository.  
1. Create a file named `db_root_password.txt` in the `secrets/` folder and put inside of it the root password for MySQL. 
1. Create a file named `db_password.txt` in the `secrets/` folder and put inside of it the password you want to use for the a non-root user named webapp. 
1. In a terminal or command prompt, navigate to the folder with the `docker-compose.yml` file.  
1. Build the images with `docker compose build`
1. Start the containers with `docker compose up`.  To run in detached mode, run `docker compose up -d`. 

## How to start the App Smith side
1. Once the application is started download the appsmith repo in the submission
2. Navigate to `http://localhost:8080/applications`
3. Upload the repo under create new then import 

Group Members:

1. Cole Saucier
2. Siyu(Cindy) Hou
3. Andrew Lotocki
4. Rishi Agarwal
5. Reagan White

Video Link: https://drive.google.com/file/d/1rguliwQ2oxgRViJGBrIC6s4vEQj6JO7m/view?usp=share_link








