FROM mcr.microsoft.com/azure-functions/python:3.0-python3.8-appservice

ENV AzureWebJobsScriptRoot=/home/site/wwwroot \
    AzureFunctionsJobHost__Logging__Console__IsEnabled=true \
    host:logger:consoleLoggingMode=always

COPY . /home/site/wwwroot
RUN cd /home/site/wwwroot && pip install -r requirements.txt

