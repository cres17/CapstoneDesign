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
    # 배포 시 MODEL_ARTIFACT_VERSION에 v3 같은 고정 버전을 지정하면 latest 변경에 영향받지 않는다
    version = os.environ.get("MODEL_ARTIFACT_VERSION", "latest")
    artifact = wandb.Api().artifact(f"{ENTITY}/{PROJECT}/{run_name}:{version}", type="model")
    model_dir = artifact.download()
    model = AutoModelForSequenceClassification.from_pretrained(model_dir).to(DEVICE)
    tokenizer = AutoTokenizer.from_pretrained(model_dir)
    return model.eval(), tokenizer

# ✅ 남성/여성 모델 로드
print("[MODEL_SERVER] 모델 다운로드 중...")
model_male, tokenizer_male = load_model("kobigbird-male-mlp-pearson")
model_female, tokenizer_female = load_model("kobigbird-female-mlp-pearson")
print("[MODEL_SERVER] 남/여 모델 로딩 완료")

# ✅ Flask 서버 초기화
app = Flask(__name__)

@app.route("/")
def index():
    return "✅ 모델 서버 정상 작동 중"

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        data = request.get_json(silent=True) or {}
        input_text = data.get("input_text", "")
        gender = str(data.get("gender", "")).lower()

        if not isinstance(input_text, str) or not input_text.strip() or gender not in ("male", "female"):
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
        # 내부 오류 내용은 서버 로그에만 남기고 응답에는 노출하지 않는다
        app.logger.exception("analyze failed: %s", e)
        return jsonify({"error": "prediction failed"}), 500

if __name__ == "__main__":
    # 디버그 모드는 Werkzeug 디버거가 외부에 열리지 않도록 기본으로 끈다 (MODEL_SERVER_DEBUG=1일 때만 사용)
    app.run(
        # 앱은 Node 서버의 /api/predict를 거쳐 호출하므로 기본은 같은 서버 안에서만 연다
        host=os.environ.get("MODEL_SERVER_HOST", "127.0.0.1"),
        port=int(os.environ.get("MODEL_SERVER_PORT", "5001")),
        debug=os.environ.get("MODEL_SERVER_DEBUG") == "1",
    )
