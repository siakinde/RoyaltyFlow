🚀 Overview
-----------

The `RoyaltyFlow` smart contract is a robust and transparent solution for **Automated Royalty Distribution for Music and Digital Content**. Built on the **Clarity** smart contract language for the **Stacks blockchain**, this contract enables fair, immutable, and instant payment distribution to multiple stakeholders (artists, producers, labels, rights-holders, etc.) based on predefined, immutable split percentages.

It addresses the fundamental challenges in content monetization---namely, opacity, high administrative costs, and delayed payments---by embedding the royalty distribution logic directly into the blockchain. Once content is **locked**, the established royalty splits are enforced for every subsequent revenue injection, ensuring every stakeholder receives their precisely calculated share without manual intervention.

### Key Features

-   **Content Registration:** Securely registers digital content with its unique ID and title, assigning an initial owner.

-   **Immutable Royalty Splits:** Allows content owners to define specific percentage splits for multiple stakeholders before the content is locked.

-   **Automatic Distribution:** Revenue deposited into the contract is instantly and proportionally distributed to all registered stakeholders based on their defined percentages.

-   **Withdrawal Mechanism:** Stakeholders can claim their accumulated **pending-balance** on-demand via the `withdraw-royalties` function.

-   **Locking Mechanism:** A crucial security feature (`lock-content`) that prevents any further changes to stakeholder lists or their percentages once the splits are finalized and validated (must sum to 100.00%).

-   **Auditability & Transparency:** All revenue, distributions, and earnings are tracked on-chain, providing a comprehensive, public, and tamper-proof audit trail.

-   **Advanced Batch Processing:** The `batch-distribute-revenue-advanced` function allows for efficient handling of complex revenue streams, supporting metadata for different sources (e.g., Spotify, Apple Music, direct sales) to enhance accounting and tax reporting.

* * * * *

📋 Contract Architecture and Data Structures
--------------------------------------------

The contract is meticulously structured using Clarity's native maps and data variables to ensure efficient data retrieval and state management.

### Constants

| Constant | Value | Description |
| --- | --- | --- |
| `percentage-precision` | `u10000` | Represents 100.00% (allows for two decimal places of precision, e.g., 25.50% is `u2550`). |
| `err-owner-only` | `u100` | Authorization error for functions restricted to the contract owner. |
| `err-not-authorized` | `u101` | General authorization error (e.g., content owner only). |
| `err-invalid-percentage` | `u103` | Used when split percentages are outside the valid range or do not sum up to `percentage-precision` upon locking. |
| `err-content-locked` | `u108` | Used when attempting to modify stakeholders or distribute revenue before content is locked. |

### Data Maps and Variables

| Map/Variable | Key/Type | Value/Type | Purpose |
| --- | --- | --- | --- |
| `content-registry` | `content-id: (string-ascii 64)` | `{ owner: principal, title: (string-utf8 256), total-revenue: uint, is-locked: bool, created-at: uint }` | Stores core content metadata and state. |
| `royalty-splits` | `{ content-id: (string-ascii 64), stakeholder: principal }` | `{ percentage: uint, total-earned: uint, pending-balance: uint }` | Tracks the split percentage, total historical earnings, and unclaimed balance for each stakeholder per content ID. |
| `content-stakeholders` | `{ content-id: (string-ascii 64), index: uint }` | `{ stakeholder: principal }` | An indexed list of all stakeholders for a given content, primarily used for efficient iteration during revenue distribution via `fold`. |
| `stakeholder-count` | `{ content-id: (string-ascii 64) }` | `{ count: uint }` | Tracks the total number of stakeholders for a content ID. |
| `total-contents` | `uint` | Global counter for all registered content. |  |
| `total-revenue-distributed` | `uint` | Global counter for the total revenue dispersed through the contract. |  |

* * * * *

🔒 Public Functions (Transactions)
----------------------------------

These functions modify the contract state and require a transaction fee.

### `register-content`

Registers new digital content with a unique ID and title. The transaction sender becomes the initial **content owner**.

Code snippet

```
(define-public (register-content (content-id (string-ascii 64)) (title (string-utf8 256)))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | A unique identifier for the content (e.g., ISRC code, CID). |
| `title` | `(string-utf8 256)` | The human-readable title of the content. |
| **Returns** | `(response bool err-already-exists)` | `ok true` on success. |

### `add-stakeholder`

Adds a new stakeholder and defines their royalty split percentage.

Code snippet

```
(define-public (add-stakeholder (content-id (string-ascii 64)) (stakeholder principal) (percentage uint)))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | The ID of the content to update. |
| `stakeholder` | `principal` | The Stacks address of the recipient. |
| `percentage` | `uint` | The royalty share in basis points (e.g., `u2500` for 25.00%). |
| **Returns** | `(response bool err-not-authorized)` | **Note:** Only callable by the content owner and before the content is locked. |

### `lock-content`

Finalizes the royalty split configuration. This is a **critical, irreversible step** that validates the total percentage and prevents future modifications to the stakeholder list.

Code snippet

```
(define-public (lock-content (content-id (string-ascii 64))))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | The ID of the content to lock. |
| **Returns** | `(response bool err-invalid-percentage)` | **Validation:** Asserts that the sum of all stakeholder percentages equals `u10000` (100%). |

### `distribute-revenue`

Initiates the automated royalty distribution for a specific content ID. The provided `amount` is instantly split and allocated to all stakeholders' `pending-balance`.

Code snippet

```
(define-public (distribute-revenue (content-id (string-ascii 64)) (amount uint)))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | The content ID receiving revenue. |
| `amount` | `uint` | The total revenue amount to be distributed. |
| **Returns** | `(response bool err-content-locked)` | **Precondition:** Content must be locked. |

### `batch-distribute-revenue-advanced`

An advanced function designed for professional environments, allowing a single transaction to process revenue from multiple sources for a given content. It calculates the total distribution amount and provides a rich summary of the transaction.

Code snippet

```
(define-public (batch-distribute-revenue-advanced (content-id (string-ascii 64)) (revenue-sources (list 5 { source: (string-ascii 32), amount: uint, timestamp: uint }))))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | The content ID receiving the batch revenue. |
| `revenue-sources` | `(list 5 { ... })` | A list of revenue events, each including `source` (e.g., "Spotify"), `amount`, and `timestamp`. |
| **Returns** | `(response { total-distributed: uint, ... } err-content-locked)` | Returns a detailed object with batch statistics. |

### `withdraw-royalties`

Allows any registered stakeholder to claim their accumulated `pending-balance`. This resets their pending balance to zero and, in a production environment, would execute the actual STX transfer.

Code snippet

```
(define-public (withdraw-royalties (content-id (string-ascii 64))))

```

| Parameter | Type | Description |
| --- | --- | --- |
| `content-id` | `(string-ascii 64)` | The content ID for which royalties are being claimed. |
| **Returns** | `(response uint err-insufficient-balance)` | Returns the amount of STX (simulated) successfully withdrawn. |

* * * * *

🔎 Read-Only Functions (Queries)
--------------------------------

These functions read the contract state without performing a transaction. They are free to call.

### `get-content-info`

Retrieves the full metadata for a specific content ID from the `content-registry`.

Code snippet

```
(define-read-only (get-content-info (content-id (string-ascii 64))))

```

### `get-stakeholder-split`

Retrieves the specific royalty split data, including percentage, total earnings, and pending balance, for a given stakeholder and content.

Code snippet

```
(define-read-only (get-stakeholder-split (content-id (string-ascii 64)) (stakeholder principal)))

```

### `get-global-stats`

Returns the global statistics tracked by the contract: the total number of registered contents and the total revenue distributed across all content.

Code snippet

```
(define-read-only (get-global-stats))

```

* * * * *

💡 Usage and Workflow Example
-----------------------------

1.  **Registration:** The artist registers a new track: `(register-content "ISRC-12345" "My Hit Single")`

2.  **Stakeholder Addition:** The artist (content owner) adds stakeholders: `(add-stakeholder "ISRC-12345" 'producer-address u1500)` (15.00%) `(add-stakeholder "ISRC-12345" 'label-address u3000)` (30.00%) (The artist implicitly retains the remaining 55.00%).

3.  **Locking:** The artist locks the content after verifying the splits sum to 100.00%: `(lock-content "ISRC-12345")`

4.  **Revenue Distribution:** A distribution platform deposits revenue: `(distribute-revenue "ISRC-12345" u1000000)` (1,000,000 units of revenue)

    -   Producer: 15.00% → 150,000 units allocated to `pending-balance`.

    -   Label: 30.00% → 300,000 units allocated to `pending-balance`.

    -   Artist: 55.00% → 550,000 units allocated to `pending-balance`.

5.  **Withdrawal:** The producer claims their earnings: `(withdraw-royalties "ISRC-12345")`

* * * * *

🛡️ Security and Validation
---------------------------

The contract employs rigorous assertion checks to maintain security and data integrity:

-   **Authorization:** All critical modification functions (`add-stakeholder`, `lock-content`) are restricted to the **content owner** (`tx-sender` must equal `content-registry.owner`).

-   **Immutability:** The `is-locked` flag is checked before allowing any revenue distribution or stakeholder modifications.

-   **Percentage Validation:** The private function `verify-total-percentage` ensures that all registered splits sum exactly to `u10000` (100.00%) before a content can be locked.

-   **Boundary Checks:** Percentage splits are validated to be between 1 and 10000 to prevent invalid distribution calculations.

-   **Gas Constraint Management:** The stakeholder count is capped at `u10` to mitigate potential issues with transaction gas limits during the distribution `fold` operation.

* * * * *

🤝 Contribution
---------------

We welcome contributions, suggestions, and security audits from the Stacks and Clarity community to enhance the robustness and feature set of `RoyaltyFlow`.

### Reporting Issues

If you find a bug, vulnerability, or have a suggestion, please open an issue in the GitHub repository (assuming this code is hosted). When reporting a bug, please include:

1.  A clear and concise description of the issue.

2.  The steps to reproduce the behavior.

3.  The expected outcome.

4.  Any relevant stack trace or transaction ID.

### Development Process

1.  Fork the repository.

2.  Create a new feature branch (`git checkout -b feature/AmazingFeature`).

3.  Implement your changes and write comprehensive unit tests using the Clarinet testing framework.

4.  Commit your changes (`git commit -m 'Add some AmazingFeature'`).

5.  Push to the branch (`git push origin feature/AmazingFeature`).

6.  Open a Pull Request (PR) against the `main` branch, ensuring all tests pass.

* * * * *

📜 License
----------

This project is licensed under the **MIT License**.

```
MIT License

Copyright (c) 2025 RoyaltyFlow

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

```

* * * * *

📞 Contact
----------

For critical inquiries, partnership opportunities, or further details on deployment, please reach out to:

-   **siakinseinde@gmail.com**

-   **https://github.com/siakinde/RoyaltyFlow/**
