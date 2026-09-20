# Mushaf Edition Decision Record

**Status**: APPROVED (for engineering, ingestion, and local verification; store release subject to Qamar written confirmation)  
**Date**: September 20, 2026  
**Approved by**: User & Antigravity  

## Decision Summary

1. **Chosen Immutable Edition ID**: `taj-company-13-847`
2. **Exact Publisher & Lithograph Edition**: Taj Company Ltd. (Lahore, Pakistan), 13-Line Color-Coded Tajweed Mushaf.
3. **Quran-Bearing Page Count**: 847 pages (Page 1 = Al-Fatihah, Page 847 = An-Nas).
4. **Supplementary Pages**: 2 concluding pages of *Dua Khatam al-Quran* (assets `850` / `851`), plus Cover and Front Matter (`00`, `000`, `001`, `002`, `003`). Total navigation pages in reader: 849.
5. **Decoupled Architecture**: Stored in a separate read-only sidecar database `mushaf_editions.sqlite`. The canonical database `quran_content.sqlite` remains 100% untouched.
6. **Legacy Fallback**: Retain the existing 849-page Core Text engine as `legacy-qudratullah-13-849` for accessible text fallback and Dynamic Type support.
7. **Asset Resolution Strategy**:
   - **Phase 1 (Immediate)**: Ingest 720 × 1057 px PNGs directly from `pipeline/qamar_app.apk`. Total size ~54 MB.
   - **Phase 2 (Polish)**: Upgrade to verified native 1162 × 1684 px scans from Qamar's web eBook with registered coordinates. No generative AI upscaling.
8. **Rights & Attribution**:
   - Sourced under Creative Commons Attribution-ShareAlike 4.0 (CC BY-SA 4.0).
   - Prominent attribution in `SettingsView`.
   - Written clarification email sent to `support@qamarapps.com`.
