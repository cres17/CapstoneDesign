# 다온 (Daon) - AI 기반 소개팅 어플리케이션

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![WebRTC](https://img.shields.io/badge/WebRTC-DA291C?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org/)
[![ML Kit](https://img.shields.io/badge/ML%20Kit-FF6F00?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![Clova Speech](https://img.shields.io/badge/Clova%20Speech-03C75A?style=for-the-badge&logo=naver&logoColor=white)](https://clova.ai/speech)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com/)
[![PyTorch](https://img.shields.io/badge/PyTorch-EE4C2C?style=for-the-badge&logo=pytorch&logoColor=white)](https://pytorch.org/)
[![WandB](https://img.shields.io/badge/W%26B-FFBE00?style=for-the-badge&logo=weightsandbiases&logoColor=black)](https://wandb.ai/)

**다온**은 Flutter 기반의 AI 소개팅 어플리케이션입니다.  
실시간 영상통화, 얼굴 마스킹, AI 대화 분석, **호감도 변화 예측**, 실시간 채팅, 데이트 장소 추천 등 다양한 기능을 제공합니다.

---

## ✨ 주요 기능

### 1. 실시간 영상통화 & 얼굴 마스킹
- **WebRTC**(`flutter_webrtc`)로 실시간 영상통화 구현
- **Google ML Kit Face Detection**으로 영상 프레임에서 얼굴 실시간 감지
- **CustomPaint**와 **dart:ui**로 얼굴 위치에 마스크 이미지 오버레이
- **RepaintBoundary**로 프레임 캡처, **path_provider**로 임시 파일 저장

---

### 2. AI 기반 대화 분석
- 통화 중 음성 녹음 → **네이버 클로바 Speech API**로 STT(음성→텍스트)
- 변환된 텍스트를 **OpenAI GPT API**로 전송, 대화 요약/감정/분위기 분석

---

### 3. 호감도 변화 예측 (Core AI)

소개팅 대화에서 발화자의 **호감도 변화**를 텍스트만으로 예측하는 자체 AI 모델입니다.  
공개 데이터셋이 없는 도메인에서 Weak Supervision 기반 Soft Labeling으로 데이터를 고도화하고,  
BiERU(양방향 GNTB) 아키텍처로 대화 전후 맥락을 학습합니다.

#### 📊 성능

| 구분 | 정확도 | F1 | MSE (회귀) | R² (회귀) |
|------|-------|----|-----------|----------|
| 남성 입장 호감도 | 0.607 | 0.756 | 0.056 | 0.587 |
| 여성 입장 호감도 | 0.536 | 0.606 | 0.045 | 0.503 |

> 실사용자 48명 대상 호감도 예측 기능 만족도: **4.22 / 5.0점**

#### 🗂️ 파이프라인 전체 흐름

```
원시 대화 데이터
      │
      ▼
[STEP 1]  라벨 스무딩 (Soft Labeling)
      │   KoBigBird CLS → 코사인 유사도 필터링
      │   → 그래프 구성 → Snorkel LabelModel
      │   → 이산 레이블(0/0.5/1)을 [0~1] 연속 확률로 변환
      │
      ▼
[STEP 2]  BiERU — 양방향 GNTB 기반 맥락 학습
      │   KoBigBird 임베딩 (max_length=4096)
      │   → GNTB로 이전/현재/이후 발화 양방향 결합
      │     (GNTB는 BiERU의 내부 순환 구조)
      │   → CNN (지역 감정) + LSTM (연속 감정) 추출
      │   → ReLU 1차원 축소
      │   → 분류(BCE) / 회귀(MSE) 이중 출력
      │
      ▼
    예측 결과 (호감도 점수 0~1)
```

#### STEP 1. 라벨 스무딩 (Soft Labeling)

직접 수집한 데이터의 레이블이 `0(하락) / 0.5(유지) / 1(상승)` 이산값으로만 구성되어  
감정의 연속적 강도와 불확실성을 반영하지 못하는 문제를 해결합니다.

**데이터 수집**
- 연애 예능 프로그램 발화 수집 (조건: 남녀 1:1 대화 + 대화 후 인터뷰 호감도 응답)
- 남성 입장 / 여성 입장 각각 `0 / 0.5 / 1` 하드 레이블 부여

**CLS 벡터 기반 노이즈 필터링**
```python
# KoBigBird CLS 벡터 추출 후 코사인 유사도로 노이즈 발화 제거
inputs = tokenizer(utterance, return_tensors="pt", truncation=True, max_length=512)
cls_vector = model(**inputs).last_hidden_state[:, 0, :]
```

**그래프 기반 라벨 전파**
- 유사 발화 간 동글 노드(연결 노드) 추가 → 그래프 구성
- **Snorkel LabelModel**으로 사후 확률 계산
- 이산 레이블 → `[0~1]` 연속 소프트 확률로 변환

```
Before:  0 ████  0.5 ██  1 ████   (3점 집중 이산 분포)
After:   ░▒▓█████▓▒░▒▓██████▓░   (다봉 연속 분포)
```

#### STEP 2. BiERU — 양방향 GNTB 기반 맥락 학습

**GNTB는 BiERU의 내부 순환 구조입니다. BiERU 자체가 양방향 GNTB이며**,  
이전/현재/이후 발화를 양방향으로 결합해 대화 흐름 속 감정 변화를 학습합니다.

```
발화 t-1 (이전)  ──┐
발화 t   (현재)  ──┤── KoBigBird 임베딩 (max_length=4096)
발화 t+1 (이후)  ──┘         │
                             ▼
                    [CLS] + [Max Pooling]
                             │
                    ┌────────┴────────┐
                    │     BiERU       │
                    │  ┌───────────┐  │
                    │  │   GNTB    │  │  ← BiERU의 내부 순환 구조
                    │  │ (양방향)  │  │
                    │  └───────────┘  │
                    └────────┬────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
           CNN Layer                   LSTM Layer
        (지역 감정 패턴)             (연속 감정 흐름)
              └──────────────┬──────────────┘
                             │
                       벡터 합성 → ReLU
                             │
                    ┌────────┴────────┐
                    │                 │
                 분류 (BCE)       회귀 (MSE)
               호감 상승 여부    호감 강도 점수
```

```python
class KoBigBirdBinaryClassifier(nn.Module):
    def __init__(self):
        super().__init__()
        self.encoder = AutoModel.from_pretrained("monologg/kobigbird-bert-base")
        hidden = self.encoder.config.hidden_size
        self.classifier = nn.Linear(hidden * 2, 1)

    def forward(self, input_ids, attention_mask):
        outputs = self.encoder(input_ids=input_ids, attention_mask=attention_mask)
        cls_emb = outputs.last_hidden_state[:, 0, :]
        pooled  = torch.max(outputs.last_hidden_state, dim=1).values
        combined = torch.cat([cls_emb, pooled], dim=-1)
        return self.classifier(combined).squeeze(-1)
```

**모델 서빙**: 학습된 가중치를 **W&B Artifacts**로 버전 관리하고, **Flask REST API**로 서빙해 Flutter 앱과 연동합니다.

> 참고: Li, Wei, et al. *"BiERU: Bidirectional emotional recurrent unit for conversational sentiment analysis."* Neurocomputing 467 (2022)  
> 참고: Pukdee, Rattana, et al. *"Label propagation with weak supervision."* arXiv:2210.03594 (2022)  
> 참고: Matsuo, Kazuya, et al. *"Enhancing Impression Change Prediction in Speed Dating Simulations."* arXiv:2502.04706 (2025)

---

### 4. 실시간 채팅 기능
- **Socket.IO** 기반의 1:1 채팅 및 채팅방 목록
- 메시지 실시간 송수신, 채팅방 입장/퇴장, 채팅 UI 제공

---

### 5. 데이트 장소 추천
- 사용자의 위치와 상대방 닉네임을 기반으로, 두 사람의 위치를 고려한 데이트 장소 추천
- **한국 관광공사 TourAPI 3.0**과 연동, 카드형 UI로 추천 장소 제공

---

### 6. 기타 기능
- **회원가입/로그인**: 사용자 정보 입력 및 인증
- **랜덤 매칭**: 서버에 접속한 사용자 중 무작위 연결
- **대화 분석/예측 결과 조회**: 카드형 UI, 상세 모달
- **설정**: 프로필 수정, 로그아웃, 회원탈퇴 등

---

## 🛠️ 사용한 주요 알고리즘 및 API

| 기능 | 기술 |
|------|------|
| 얼굴 인식 | Google ML Kit Face Detection (bounding box 추출) |
| 음성 인식(STT) | 네이버 클로바 Speech API |
| 대화 분석/요약 | OpenAI GPT API (텍스트 요약, 감정 분석) |
| 호감도 예측 | KoBigBird + BiERU(GNTB) + Snorkel Soft Labeling |
| 실험 관리 | W&B (Weights & Biases) Artifacts |
| 실시간 통신 | WebRTC (`flutter_webrtc`), Socket.IO |
| 장소 추천 | 한국 관광공사 TourAPI 3.0 |
| 상태 관리 | Provider |
| 이미지 처리 | image, image_picker, cached_network_image |

---

## 📱 화면 구성

- **시작 페이지**: 앱 소개, 로그인/회원가입 버튼
- **회원가입 페이지**: 아이디, 비밀번호, 성별, 주소, 닉네임, 프로필 사진 입력
- **로그인 페이지**: 아이디, 비밀번호 입력
- **메인 페이지**: 하단 네비게이션(메인, 데이트 장소 추천, 채팅방, 설정), 상대방 연결 버튼, 상단 네비게이션(대화 분석, 예측 결과)
- **영상통화 페이지**: 얼굴 마스킹 적용된 영상통화
- **대화분석 페이지**: 통화별 분석 결과 카드, 상세 모달
- **호감도 예측 페이지**: 통화별 호감도 예측 결과 카드, 상세 모달
- **데이트 장소 추천 페이지**: 두 사람의 위치 기반 추천 장소 카드 UI
- **채팅방 페이지**: 1:1 채팅, 채팅방 목록, 실시간 메시지
- **설정 페이지**: 주소 수정, 로그아웃, 회원탈퇴

---

## 🚀 시작하기

**1. 저장소 클론**
```bash
git clone https://your-repository-url/daon.git
cd daon
```

**2. 필요한 라이브러리 설치**
```bash
flutter pub add flutter_webrtc socket_io_client permission_handler path_provider \
  google_mlkit_face_detection image http shared_preferences provider \
  image_picker cached_network_image flutter_svg intl cupertino_icons flutter_lints
```

**3. Flutter 앱 실행**
```bash
flutter run
```

---

## 📁 파일 구조 (AI 모델)

```
.
├── soft_labeling.ipynb          # Soft Labeling 파이프라인
├── classification-male.ipynb    # 남성 입장 분류 모델
├── classification-female.ipynb  # 여성 입장 분류 모델
├── model_train_male.ipynb       # 남성 입장 회귀 모델
├── model_train_female.ipynb     # 여성 입장 회귀 모델
└── 라벨값_시각화.ipynb           # 라벨 분포 시각화
```

---

## 🤝 기여하기

프로젝트에 기여하고 싶으시다면 언제든지 환영합니다! 이슈를 등록하거나 Pull Request를 보내주세요.

## 📄 라이선스

(라이선스를 명시하고 싶다면 여기에 추가하세요. 예: MIT License)

---

Made by **다온**
