FROM python:3-slim
WORKDIR /app
COPY . .
EXPOSE 8080
CMD ["python", "server.py"]
