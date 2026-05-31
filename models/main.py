from fastapi import FastAPI, File, UploadFile
import cv2
import numpy as np

# Wrapping imports in case of catastrophic python environment failure
try:
    from ultralytics import YOLO
    from tensorflow.keras.models import load_model
    import tensorflow as tf
    from tensorflow.keras.layers import Dense
    
    # Custom wrapper to strip rogue quantization_config from Keras 2/3 translation
    class CustomDense(Dense):
        def __init__(self, **kwargs):
            kwargs.pop('quantization_config', None)
            super().__init__(**kwargs)
            
except Exception as e:
    print(f"Library Import Error: {e}")

app = FastAPI()

# Global variables for models
yolo_model = None
cnn_model = None
startup_error = None

# Graceful loading so the server doesn't crash on Boot-up (prevents exit code 128)
try:
    print("Loading YOLOv8 model...")
    yolo_model = YOLO("best_v1.pt")
    print("Loading CNN model...")
    cnn_model = load_model("best_model.h5", custom_objects={'Dense': CustomDense})
    print("All models loaded successfully!")
except Exception as e:
    startup_error = str(e)
    print(f"FAILED TO LOAD MODELS: {startup_error}")


@app.get("/")
def home():
    if startup_error:
        return {"message": "Server is running, but models failed to load.", "error": startup_error}
    return {"message": "Fruit Freshness API is running 🚀", "status": "Healthy"}

@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    if yolo_model is None or cnn_model is None:
        return {"error": "Models are not loaded correctly. Check server logs.", "details": startup_error}

    try:
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        results = yolo_model(image, conf=0.5)

        freshness_list = []
        fruit_name = "Unknown"

        for r in results:
            boxes = r.boxes.xyxy.cpu().numpy()
            classes = r.boxes.cls.cpu().numpy()

            for box, cls in zip(boxes, classes):
                x1, y1, x2, y2 = map(int, box)

                crop = image[y1:y2, x1:x2]
                if crop.size == 0:
                    continue

                crop = cv2.resize(crop, (224, 224)) / 255.0
                inp = np.expand_dims(crop, axis=0)

                pred = cnn_model.predict(inp, verbose=0)[0][0]
                freshness_list.append(float(pred))

                # Safeguard against missing names
                if hasattr(yolo_model, 'names') and int(cls) in yolo_model.names:
                    fruit_name = yolo_model.names[int(cls)]

        if not freshness_list:
            return {"fruit": "No fruit detected", "average_freshness": 0.0, "status": "Unknown", "total_detected": 0}

        avg = sum(freshness_list)/len(freshness_list)

        # grading
        if avg > 0.7:
            status = "Fresh"
        elif avg > 0.4:
            status = "Medium"
        else:
            status = "Rotten"

        return {
            "fruit": fruit_name,
            "average_freshness": round(avg, 2),
            "status": status,
            "total_detected": len(freshness_list)
        }
    except Exception as e:
        return {"error": "Prediction process failed", "details": str(e)}
