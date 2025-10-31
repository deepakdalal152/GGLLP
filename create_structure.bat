@echo off
REM =============================================
REM Batch script to create GGLLP VFX Automation folder structure
REM Fully expandable and modular
REM =============================================

REM Create main root folder with version
mkdir 2.0.0
cd 2.0.0

REM Core automation code and configs
mkdir automation
mkdir automation\config
mkdir automation\scripts
mkdir automation\utils
mkdir automation\tests

REM Folder for isolated docker-compose files to test individual services
mkdir dockers

REM Documentation folder
mkdir docs

REM --------------- Create empty config files ---------------
type nul > automation\config\auth_config.yaml
type nul > automation\config\jumpserver_config.yaml
type nul > automation\config\ayon_config.yaml
type nul > automation\config\kitsu_config.yaml
type nul > automation\config\hrms_config.yaml
REM Add more config files here as you expand

REM --------------- Create empty automation scripts ---------------
type nul > automation\scripts\sync_hrms_to_authentik.py
type nul > automation\scripts\sync_authentik_to_jumpserver.py
type nul > automation\scripts\sync_ayon_projects.py
type nul > automation\scripts\sync_kitsu_tasks.py
type nul > automation\scripts\assign_jumpserver_access.py
type nul > automation\scripts\offboarding.py
REM Add new sync or helper scripts here as needed

REM --------------- Create utility helper files ---------------
type nul > automation\utils\api_client.py
type nul > automation\utils\logger.py
type nul > automation\utils\helpers.py

REM --------------- Create test files for automation scripts ---------------
type nul > automation\tests\test_sync_hrms.py
type nul > automation\tests\test_authentik.py
type nul > automation\tests\test_jumpserver.py
REM Expand tests folder with more unit/integration tests

REM --------------- Docker-related files inside automation ---------------
type nul > automation\Dockerfile
type nul > automation\requirements.txt
type nul > automation\README.md
type nul > automation\run_all.sh
REM Add more automation container support files here

REM --------------- Compose test files for isolated service dev ---------------
type nul > dockers\0200.authentik.docker
type nul > dockers\0400.jumpserver.docker
type nul > dockers\0100.frappe.docker
type nul > dockers\0310.kitsu.docker
type nul > dockers\0300.ayon.docker
type nul > dockers\0500.automation.docker
REM Add new compose files per service or environment

REM --------------- Main compose and env files ---------------
type nul > docker-compose.yml
type nul > docker-compose.override.yml
type nul > .env

REM --------------- Documentation files ---------------
type nul > docs\workflow.md
type nul > docs\api_specs.md
type nul > docs\troubleshooting.md
REM Add more docs as your system grows

echo.
echo GGLLP VFX Automation folder structure created successfully!
echo You can now add your code, configs, and expand the project easily.
pause
