# 🌱 Relife AI

## AI-Powered Food Freshness Monitoring & Smart Redistribution Platform

Relife AI is an intelligent inventory monitoring system that combines Artificial Intelligence, Computer Vision, IoT sensors, and cloud technologies to reduce food wastage and improve inventory management.

The platform analyzes food freshness using AI, monitors storage conditions in real time, and helps businesses make smarter decisions such as selling, discounting, or donating products before they become waste.

---

## 🚀 Problem Statement

Traditional inventory systems rely heavily on static expiry dates and manual inspections.

However:

- Products can spoil before their expiry date
- Environmental conditions affect shelf life
- Businesses lack real-time visibility into product freshness
- Large amounts of edible food are wasted every day

Relife AI addresses these challenges through AI-powered freshness analysis and real-time environmental monitoring.

---

## ✨ Key Features

### 🤖 AI Freshness Detection
- YOLOv8 for multi-object fruit and vegetable detection
- MobileNetV2 CNN for freshness analysis
- Individual item-level freshness scoring
- Crate-level freshness evaluation

### 🌡️ Environmental Monitoring
- ESP32-based IoT system
- DHT22 temperature and humidity sensing
- Real-time storage condition monitoring
- Environmental risk assessment

### 📊 Smart Decision Engine
- Freshness score calculation
- Shelf-life evaluation
- Automated recommendations:
  - Sell
  - Discount
  - Donate

### 🤝 NGO Redistribution
- Connects stores with NGOs
- Reduces food wastage
- Enables surplus food donation workflow

### ☁️ Cloud Integration
- Supabase backend
- Real-time data synchronization
- Secure data storage

---

## 🏗️ System Architecture

```text
Storage Environment
       │
       ▼
DHT22 + ESP32 Sensors
       │
       ▼
Supabase Cloud Database
       │
       ▼
Product Image
       │
       ▼
YOLOv8 Detection
       │
       ▼
MobileNetV2 Freshness Analysis
       │
       ▼
Freshness Score Generation
       │
       ▼
Decision Engine
       │
       ▼
Sell / Discount / Donate
```

---

## 🧠 Technologies Used

### Artificial Intelligence
- YOLOv8
- MobileNetV2
- TensorFlow
- OpenCV

### IoT Hardware
- ESP32
- DHT22 Temperature & Humidity Sensor
- OLED Display

### Backend & Cloud
- Supabase
- REST APIs

### Frontend
- Flutter

### Programming Languages
- Python
- Dart
- C++

---

## 📋 Algorithms Used

### YOLOv8
Detects multiple fruits and vegetables within a single image.

### MobileNetV2
Analyzes freshness based on:
- Color changes
- Surface defects
- Texture variations

### Rule-Based Decision Logic
Generates recommendations:
- Sell
- Discount
- Donate

### Environmental Risk Logic
Adjusts freshness understanding using:
- Temperature
- Humidity

---

## 🔄 Workflow

1. Capture product image
2. Detect products using YOLOv8
3. Analyze freshness using MobileNetV2
4. Collect temperature and humidity data
5. Calculate overall freshness score
6. Generate recommendations
7. Connect eligible inventory with NGOs

---

## 📈 Future Scope

- Automated shelf-life prediction models
- Nearest NGO detection using geolocation
- Thermal camera integration
- Multi-store inventory management
- Warehouse-scale monitoring
- Automated donation scheduling
- Food bank integration
- Explainable AI insights
- Smart chatbot assistant

---

## 🎯 Impact

Relife AI helps:

- Reduce food waste
- Improve inventory visibility
- Support sustainability initiatives
- Enable food redistribution
- Improve operational efficiency

---

## 👥 Team

**BotWorks**

### Tagline
**Giving Food a Second Life Through AI.**
