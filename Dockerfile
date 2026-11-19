FROM python:3.12-slim
WORKDIR /app
COPY index.html styles.css app.js server.py data.json ./
EXPOSE 8765
CMD ["python3", "server.py"]
