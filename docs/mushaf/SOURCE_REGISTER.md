# Source Register: Authentic Mushaf Assets

## 1. Candidate Sources Registry

### Source Candidate 1: Qamar Apps Android Package (Audited Baseline)
- **File**: `pipeline/qamar_app.apk`
- **SHA-256**: `a48644f6735ac690130d449577a0c44c4fc981533f489974f0446beff1a629a3`
- **Image Assets**: 853 PNG files under `assets/www/book/Images/`
- **Dimensions**: 720 × 1057 px (851 pages), 640 × 1136 px (1 page - splash), 720 × 1043 px (1 page).
- **Coordinate Maps**: 852 HTML files under `assets/www/book/Html/`
- **Quranic Mapped Pages**: 847 pages (source `004` to `850`)
- **Total Bounding Rectangles**: 15,903
- **Known Coordinate Defects**: Source `522.html` has zero-area coordinates (`0,0,0,0`) for Ash-Shu'ara 26:143 and 26:144. (Patched in pipeline).
- **Licensing**: Public declaration at `qamarapps.com/license` states CC BY-SA 4.0. In-app notice has standard copyright reservation. Written clarification requested.
- **Status**: **APPROVED for Phase 1 Baseline Ingestion**.

### Source Candidate 2: Qamar Apps First-Party Web eBook
- **Base URL**: `https://ebooks.qamarapps.com/ebooks/quran-13-line/HTML/`
- **Image Substrates**: `files/assets/common/page-substrates/pageNNNN.png`
- **Dimensions**: 1162 × 1684 px (~2.9× pixel density vs APK).
- **Identity Verification**: Empirically confirmed 100% calligraphic and page-by-page identity with Candidate 1. Includes 40px bottom Tajweed legend bar. Index offset is `Web = APK + 2`.
- **Coordinate Maps**: Requires coordinate registration (~1.614× linear scale).
- **Status**: **CANDIDATE for Phase 2 High-Definition Upgrade**.

### Source Candidate 3: Internet Archive 300 PPI Master (`13-line-quran-with-beautiful-color-coded-tajweed-rules-pdf`)
- **Format**: PDF / JP2 derivative (3301 × 5100 px canvas).
- **Audit Finding**: Sample inspection shows embedded images are 720 × 1057 px scaled into a larger derivative canvas.
- **Status**: Not recommended as high-res upgrade.

---

## 2. Pinned Canonical Checksum
- **Canonical Database**: `QuranApp/Resources/Database/quran_content.sqlite`
- **SHA-256 Checksum**: `468a57eccd63f8796d859ae3c40751e73722e0e09ef2f92f2fc74305888ad9c0`
- **Status**: Untouched, passing 51/51 integrity checks.
