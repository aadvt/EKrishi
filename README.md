# E-Krishi (ಇ-ಕೃಷಿ)

**Fair prices for every farmer.**

E-Krishi is a mobile application designed to empower farmers by providing real-time fair market pricing estimates for their produce. By combining advanced AI image recognition with localized market data, E-Krishi helps farmers make informed decisions at the mandi.

---

## 📸 Screenshots
*(Coming soon — Module 1 Online MVP)*

---

## 🚀 Setup Instructions

Follow these steps to get the project running locally:

### 1. Clone the repository
```bash
git clone https://github.com/aadvt/EKrishi.git
cd EKrishi
```

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Setup environment variables
Create a `.env` file in the root directory and add your API keys:
```env
GEMINI_API_KEY=your_gemini_key_here
AGMARKNET_API_KEY=your_agmarknet_key_here
GOOGLE_MAPS_API_KEY=your_google_maps_key_here
```

### 4. Run the app
Ensure you have a device connected or an emulator running:
```bash
flutter run
```

---

## 🔑 Required API Keys

To full use all features, you will need the following (all have free tiers):
- **Gemini API Key**: Obtain from [Google AI Studio](https://aistudio.google.com/). Used for produce identification and price reasoning.
- **Agmarknet API Key**: Register at [data.gov.in](https://data.gov.in/) to access historical and live mandi prices.
- **Google Maps API Key**: Available via [Google Cloud Console](https://console.cloud.google.com/). Used for precise location detection.

---

## ✨ Features (Module 1 — MVP)
- ✅ **AI Produce Recognition**: Identify fruits and vegetables instantly using your camera.
- ✅ **Bilingual Support**: Full interface in both **English** and **Kannada**.
- ✅ **Local Market Pricing**: Receive fair price estimates based on your current district and state.
- ✅ **GPS Location**: Automatic location detection with manual override options.
- ✅ **Scan History**: Keep a log of all previous scans for future reference.
- ✅ **Offline Persistence**: Price data is cached to ensure functionality even in low-connectivity areas.

---

## 🗺️ Planned Roadmap
- [ ] **On-Device Models**: Fully offline produce identification.
- [ ] **Voice Input**: Search and navigate the app using voice commands in Kannada.
- [ ] **Market Trends**: Interactive charts showing price fluctuations over time.
- [ ] **Transaction Ledger**: Track sales and income directly within the app.

---

## 📄 License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
