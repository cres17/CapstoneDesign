# model_server.py
import os
import torch
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForSequenceClassification
import wandb

ENTITY = "cres4205-sangmyung-university"
PROJECT = "huggingface"
DEVICE = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# ✅ W&B 모델 로드 함수
def load_model(run_name):
    artifact = wandb.Api().artifact(f"{ENTITY}/{PROJECT}/{run_name}:latest", type="model")
    model_dir = artifact.download()
    model = AutoModelForSequenceClassification.from_pretrained(model_dir).to(DEVICE)
    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    return model.eval(), tokenizer

# ✅ 남성/여성 모델 로드
print("[MODEL_SERVER] 모델 다운로드 중...")
model_male, tokenizer_male = load_model("kobigbird-male-regression-labeled")
model_female, tokenizer_female = load_model("kobigbird-female-regression-labeled")
print("[MODEL_SERVER] 남/여 모델 로딩 완료")

# ✅ Flask 서버 초기화
app = Flask(__name__)

@app.route("/")
def index():
    return "✅ 모델 서버 정상 작동 중"

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        data = request.get_json()
        input_text = data.get("input_text", "")
        gender = data.get("gender", "").lower()

        if not input_text or gender not in ("male", "female"):
            return jsonify({"error": "input_text and gender(male/female) are required"}), 400

        model, tokenizer = (model_male, tokenizer_male) if gender == "male" else (model_female, tokenizer_female)

        inputs = tokenizer(
            input_text,
            return_tensors="pt",
            truncation=True,
            padding="max_length",
            max_length=512
        ).to(DEVICE)

        with torch.no_grad():
            logits = model(**inputs).logits
            score = torch.sigmoid(logits).squeeze().tolist()

        return jsonify({"score": score})

    except Exception as e:
        print("[ERROR]", e)
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)
