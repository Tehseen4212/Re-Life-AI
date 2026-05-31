FROM python:3.9-slim

WORKDIR /app

# Prevent interactive prompts during apt-get
ENV DEBIAN_FRONTEND=noninteractive

# Install critical system libraries so OpenCV never crashes
RUN apt-get update && apt-get install -y libglib2.0-0 libsm6 libxext6 libxrender-dev libgl1 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

# Upgrade pip first, then install requirements
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of your app, including the models
COPY . .

# Hugging face container port
EXPOSE 7860

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "7860"]
