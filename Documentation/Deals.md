#  Deals

This document lists the requirements for limits and stops when working with positions and working orders:

## Positions
- `POST`
  - Limits can be `.distance` or `.position`.
  - Stops can be `.distance` or `.position`.
  - *Trailing* stops are only allowed for `.distance` and shall set include the *trailing increment* value.
  - *Guaranteed* stops (`Bool`) are not allowed for *trailing* stops.
- `GET`
  - Limits are only `.position`.
  - Stops are only `.position`. 
  - Trailing stops are indicated as both trailing `distance` and `increment`.
  - Stop risk is indicated (both as a Boolean *guaranteed* and number premium).
- `PUT`
  - Limits can only be `.position`.
  - Stops can only be `.position`.
  - Trailing stops can be included/modified/deleted by setting the Boolean *activation*, trailing `distance`, and `increment`).
  - By using the `PUT` endpoint, the risk becomes `exposed`.

## Working Orders
- `POST`
  - Limits can be `.distance` and `.position`.
  - Stops can be `.distance` and `.position`.
  - Only `.distance` stops can be *guaranteed*.
- `GET`
  - Limits are only `.distance`.
  - Stops are only `.distance`.
  - Stop risk is indicated (both as a Boolean *guaranteed* and number premium).
- `PUT`
  - Limits can be `.distance` and `.position`.
  - Stops can be `.distance` and `.position`.
  - By using the `PUT` endpoint the risk becomes `exposed`.

## Confirmation
- `GET`
  - Limits set one of `.distance` or `.position`.
  - Stops set one of `.distance` or `.position`.
  - Trailing stops are marked with a Boolean.
  - Guaranteed stops are marked with a Boolean.

## Activity
- `GET`
  - Limits set both `.distance` and `.position` (or both nil).
  - Stops set both `.distance` and `.position` (or both nil).
  - Trailing set both the trailing `distance` and `increment` (or both nil).
  - Guaranteed stops are marked with a Boolean.
