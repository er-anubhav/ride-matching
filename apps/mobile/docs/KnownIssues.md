# Known Issues & Technical Debt

1. **Unit & Widget Test Coverage**:
   - Automated unit tests and UI widget tests currently have low coverage (<15%).
2. **Offline Local Cache**:
   - Ride history is fetched directly via REST without offline SQLite/Hive caching when offline.
3. **Card/UPI Payments**:
   - Razorpay/Stripe SDK binding for in-app digital card payments is planned for Post-Pilot V2 (pilot operates on Cash on Delivery / COD).
