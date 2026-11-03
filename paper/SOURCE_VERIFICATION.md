# Source verification (2026-11-03)

The paper uses bibliographic entries only within the evidence scope below. It does not transfer published accuracy, performance, or calibration results to this prototype.

| Supplied source | Verification and allowed use |
| --- | --- |
| Abdrabou2025Shoulder, DOI 10.1007/978-3-032-05005-2_3 | Springer chapter page confirms title, authors, 2025 first-online date, pages 46-68 and abstract. Used for natural shoulder-surfing methodology only. https://link.springer.com/chapter/10.1007/978-3-032-05005-2_3 |
| Lei2021 iScreen, DOI 10.1109/SWC50871.2021.00012 | IEEE proceedings table of contents confirms title and five authors; bibliographic record confirms pages 9-16 and DOI. Full methods not inspected, so no detailed performance or architecture claim. Primary proceedings listing: https://www.proceedings.com/content/061/061154webtoc.pdf |
| Huo2025 AES, DOI 10.1371/journal.pone.0328297 | PLOS page confirms Mingyi Huo, Yanpei Zheng, Jun Huang, title, 20(7), e0328297, and 2025 date. Its hyperchaotic image method is not the app's AES-GCM construction. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0328297 |
| Liu2025 Monocular, DOI 10.1038/s41598-025-97568-1 | Scientific Reports page confirms authors, title, volume 15, article 12860, 2025. Used only to identify an unrelated potential depth-estimation direction; no depth model is implemented here. https://www.nature.com/articles/s41598-025-97568-1 |
| Zeeshan/Moradpoor/La Spada2026 Observer-Aware Runtime Exposure Mitigation | Institutional search result lists the title/authors as a paper presentation, but opening the record was blocked (403). Full metadata, SafeComp venue status, contents and user-supplied ResearchGate ID 406502212 remain unverified. Preserved separately and not cited for evidence. |
| Prasad2026 From Screen Exposure to Street-Level Risk | No authoritative record retrieved for user-supplied DOI 10.13140/RG.2.2.22618.30400 / ResearchGate 404821939. Preserved separately and not cited for evidence. |

Additional verified primary sources:

- Chen, Liu, Gao and Han, MobileFaceNets, arXiv:1804.07573 (2018): https://arxiv.org/abs/1804.07573 . Cited for architecture only; published benchmark values are not transferred to the app or artifact.
- Pinned model provenance is recorded in `assets/models/README.md`: repository `MCarlomagno/FaceRecognitionAuth`, commit `82372440f26d699e13996014a01805f925dbcdbb`, SHA-256 `be4bc7cfc53f7bc336d0f28b1ab92535f618c913a422b683210750f6b5354854`. Hosting repository BSD-3-Clause does not establish separate weight/dataset rights. The paper explicitly retains that limitation.

- Google ML Kit documentation explicitly says detection does not recognize individuals: https://developers.google.com/ml-kit/vision/face-detection
- NIST SP 800-38D defines GCM authenticated encryption: https://csrc.nist.gov/pubs/sp/800/38/d/final
- Kannala and Brandt author-hosted paper explains why pinhole projection does not model a hemispherical fisheye: https://users.aalto.fi/~kannalj1/calibration/Kannala_Brandt_calibration.pdf
- Kenko manufacturer's REAL PRO brochure search index and official product page document nominal 180-degree fisheye; no exact projection or measured face-detection field was found: https://kenkoglobal.com/download/document/5b9a723253911.pdf and https://www.kenko-tokina.co.jp/imaging/mobile_accessory/filter-conversion/discontinued/4961607797327.html
- Hi-Link manufacturer manual V1.02 lists +/-60-degree detection angle, up to three targets, 6 m reference range and 10 Hz updates. Its horizontal specification is not a tabletop measurement. Official product/download listing: https://hlktech.com/Goods-226.html . The supplied 70-degree vertical angle was not confirmed in this revision and is marked accordingly.
- Hi-Link serial protocol V1.03 (dated 2023-10-17) documents target coordinates: https://h.hlktech.com/download/HLK-LD2450-24G/1/LD2450%20%E4%B8%B2%E5%8F%A3%E9%80%9A%E4%BF%A1%E5%8D%8F%E8%AE%AE%20V1.03.pdf

Geometry values are owner-supplied references or explicitly chosen scenarios, not literature-derived device calibration. No empirical project measurements were supplied. Source settings and integration report establish implementation claims only; they do not establish hardware or biometric performance.
