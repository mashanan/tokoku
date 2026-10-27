# Tokoku

[![CI](https://github.com/mashanan/tokoku/actions/workflows/ci.yml/badge.svg)](https://github.com/mashanan/tokoku/actions/workflows/ci.yml)

Tokoku is a small online shop for Android and iOS, built with Flutter and Firebase. I made it as a portfolio project, so the goal wasn't to launch a store. I wanted to build one complete flow that actually works end to end: browse, add to cart, check out, and follow the order until it's delivered, plus the admin side that moves it along.

It isn't published on any app store. You can run it from source in a few minutes (see below).

## Try it

The app opens straight into the shop, so you can browse without an account. For everything else there are two demo accounts, and both also have a one-tap button on the sign-in screen:

| Role | Email | Password |
| --- | --- | --- |
| Shopper | demo.shopper@example.com | DemoShopper!2026 |
| Admin | demo.admin@example.com | DemoAdmin!2026 |

These accounts are shared with everyone who reads this, so please don't type real personal details into them.

A good way to see the whole thing: place an order as the shopper, sign in as the admin and move it through processing, shipped and delivered, then switch back to the shopper and leave a review.

## What it does

**For shoppers**

- Browse about 190 products with search, category filters and sorting (price, rating, discount)
- Save products to a wishlist
- A cart that remembers what you ticked for checkout and never lets you go over the stock
- An address book, so checkout is mostly a couple of taps
- Checkout with standard or express delivery and a few payment options (payments are simulated)
- Order history with a status timeline, cancelling while an order is still pending, and reviews once it's delivered
- Sign-up with email verification

**For admins**

- Process orders: start processing, mark as shipped, mark as delivered, or cancel and restock
- Add, edit and remove products, including photo uploads
- Import the demo catalog again whenever it gets messy

The layout adapts to the screen: a bottom bar on phones, a side rail on tablets, and two-pane pages where there's room.

## Built with

- **Flutter** 3.47 and **Dart** 3.13
- **Riverpod** for state and **go_router** for navigation
- **Firebase Auth** and **Cloud Firestore**
- Product data from [DummyJSON](https://dummyjson.com), imported once into Firestore
- **GitHub Actions** for analysis, tests and an APK build on every push

## How the code is organised

The code is split by feature rather than by type, so everything about the cart lives in one place:

```
lib/
├── core/        shared pieces: routing, theme, responsive breakpoints, widgets
└── features/
    ├── auth/        sign-in, sign-up, email verification
    ├── products/    catalog, search, sorting, product page
    ├── cart/        cart and item selection
    ├── checkout/    placing an order
    ├── orders/      history and order status
    ├── reviews/     ratings and reviews
    ├── wishlist/
    ├── addresses/
    ├── profile/
    └── admin/       order and product management
```

Inside each feature, `domain/` holds plain Dart models and rules, `data/` talks to Firebase, and `presentation/` has the screens. Screens never call Firebase directly, which made the business logic easy to unit test.

## Decisions worth knowing about

I kept the whole project on Firebase's free plan. That shaped a few things, and I'd do them differently in a real product:

- **Photos are stored as Base64 in Firestore** instead of Cloud Storage, which needs the paid plan. Images are resized and compressed before upload and kept in their own collection, so they don't slow down product reads.
- **Checkout runs on the client** in a single Firestore transaction: it re-checks stock, saves the order, lowers stock and clears the cart together. Without Cloud Functions, the security rules have to allow customers to lower stock, put it back when they cancel, and update a product's rating when they review it. The rules keep each of these tightly scoped (only alongside a real order, cancellation or first review), but they can't check exact quantities. A Cloud Function would close that gap.
- **Payments are simulated.** No money moves and no card details are collected.
- **Roles can't be changed from the app at all**, not even by admins, because the demo admin account is public. Roles are set in the Firebase console.
- **iOS is configured but untested.** I don't have a Mac, so I've only run the app on Android.

## Tests

- `flutter test` runs 38 unit and widget tests: cart totals and selection, sorting and search, order rules, navigation redirects and a few layout checks.
- `firestore-tests/` has 37 tests for the security rules, run against the Firestore emulator. They cover who can read and write what, including the cancellation and review cases above. I also checked that they catch problems by loosening a rule on purpose and watching them fail.

Both run in CI on every push, and the APK only builds when they pass.

## Running it locally

You'll need Flutter 3.47 and an Android device or emulator.

```bash
git clone https://github.com/mashanan/tokoku.git
cd tokoku
flutter pub get
flutter run
```

The app connects to my Firebase project out of the box, so the catalog and the demo accounts work right away. To use your own project instead, run `flutterfire configure`, deploy the rules with `firebase deploy --only firestore`, and use **Import demo catalog** in the admin panel to fill the shop.

To run the security rule tests you also need Node.js and Java (the emulator runs on Java):

```bash
cd firestore-tests
npm ci
npm test
```

## Contact

Built by [@mashanan](https://github.com/mashanan). Feedback and questions are welcome, so feel free to open an issue.
