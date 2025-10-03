;; astrofund-mission-escrow.clar
;; A decentralized escrow and milestone payment system for space missions,
;; enabling transparent funding and verifiable progress through Stacks smart contracts.

;; --- Contract Metadata ---
(define-constant CONTRACT-VERSION u1)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MISSION-ID (err u101))
(define-constant ERR-MISSION-NOT-PROPOSED (err u102))
(define-constant ERR-MISSION-NOT-ACTIVE (err u103))
(define-constant ERR-MISSION-ALREADY-FUNDED (err u104))
(define-constant ERR-MISSION-ALREADY-CANCELED (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))
(define-constant ERR-INVALID-MILESTONE-ID (err u107))
(define-constant ERR-MILESTONE-ALREADY-ACHIEVED (err u108))
(define-constant ERR-MILESTONE-ALREADY-PAID (err u109))
(define-constant ERR-MILESTONE-NOT-APPROVED (err u110))
(define-constant ERR-INSUFFICIENT-APPROVERS (err u111))
(define-constant ERR-ALREADY-APPROVED (err u112))
(define-constant ERR-COMMITTEE-MEMBER-ALREADY-REGISTERED (err u113))
(define-constant ERR-COMMITTEE-MEMBER-NOT-REGISTERED (err u114))
(define-constant ERR-INVALID-INPUT (err u115))
(define-constant ERR-ZERO-ADDRESS (err u116))
(define-constant ERR-MISSION-NAME-TOO-LONG (err u117))
(define-constant ERR-MILESTONE-DESCRIPTION-TOO-LONG (err u118))
(define-constant ERR-PAYOUT-AMOUNT-EXCEEDS-REMAINING-FUNDS (err u119))
(define-constant ERR-REFUND-ALREADY-PROCESSED (err u120))
(define-constant ERR-MISSION-NOT-CANCELED (err u121))
(define-constant ERR-CANNOT-SET-ZERO-APPROVALS (err u122))
(define-constant ERR-MILESTONE-AMOUNT-EXCEEDS-MISSION-TARGET (err u123))
(define-constant ERR-TRANSFER-FAILED (err u124))

;; Status constants
(define-constant STATUS-PROPOSED "Proposed")
(define-constant STATUS-ACTIVE "Active")
(define-constant STATUS-CANCELED "Canceled")
(define-constant STATUS-COMPLETED "Completed")

;; --- Data Maps and Variables ---

;; Contract deployer/administrator
(define-data-var contract-owner principal tx-sender)

;; Next available ID for new missions
(define-data-var next-mission-id uint u1)

;; Next available ID for new milestones
(define-data-var next-milestone-id uint u1)

;; Number of committee members required to approve a milestone
(define-data-var required-approvals uint u2)

;; Map for mission details: mission-id -> { name, proposer, total-funding-target, current-funds-held, status }
(define-map mission-data uint {
    mission-name: (string-ascii 100),
    proposer: principal,
    total-funding-target: uint,
    current-funds-held: uint,
    status: (string-ascii 50)
})

;; Map for individual milestones: milestone-id -> { mission-id, description, amount-to-release, is-achieved, is-paid }
(define-map milestones uint {
    mission-id: uint,
    description: (string-ascii 256),
    amount-to-release: uint,
    is-achieved: bool,
    is-paid: bool
})

;; Map to track approvals for each milestone: (milestone-id, approver-principal) -> bool
(define-map milestone-approvals { milestone-id: uint, approver: principal } bool)

;; Map for committee members: principal -> bool
(define-map committee-members principal bool)

;; Map to track if a funder has withdrawn their funds from a canceled mission: (mission-id, funder-principal) -> bool
(define-map funder-refunds { mission-id: uint, funder: principal } bool)

;; Total funds contributed by each funder for a mission: (mission-id, funder-principal) -> uint
(define-map funder-contributions { mission-id: uint, funder: principal } uint)

;; --- Private Helper Functions ---

(define-private (assert-is-contract-owner)
  (ok (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)))

(define-private (is-committee-member (account principal))
  (default-to false (map-get? committee-members account)))

(define-private (assert-is-committee-member)
  (ok (asserts! (is-committee-member tx-sender) ERR-NOT-AUTHORIZED)))

(define-private (assert-is-mission-proposer (mission-id uint))
  (let
    ((mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID)))
    (ok (asserts! (is-eq tx-sender (get proposer mission)) ERR-NOT-AUTHORIZED))))

(define-private (count-approvals-for-member (member principal) (state { milestone-id: uint, count: uint }))
  (if (default-to false (map-get? milestone-approvals { milestone-id: (get milestone-id state), approver: member }))
      { milestone-id: (get milestone-id state), count: (+ (get count state) u1) }
      state))

(define-private (get-num-milestone-approvals (milestone-id uint))
  (let
    ((all-members (list 
      tx-sender ;; Placeholder - in production, iterate over actual committee members
    )))
    (get count (fold count-approvals-for-member all-members { milestone-id: milestone-id, count: u0 }))))

;; Mock function to simulate getting a Unix timestamp.
;; In a real scenario, this would ideally come from an oracle.
(define-private (get-time-unix)
    u1678886400) ;; Example: March 15, 2023 12:00:00 PM UTC

;; --- Public Functions ---

;; --- Administration Functions ---

;; @desc Adds a new principal as an authorized committee member.
;; @param new-member The principal to add to the committee.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (add-committee-member (new-member principal))
  (begin
    (try! (assert-is-contract-owner))
    (asserts! (is-committee-member new-member) ERR-COMMITTEE-MEMBER-ALREADY-REGISTERED)
    (ok (map-set committee-members new-member true))
  ))

;; @desc Removes an existing authorized committee member.
;; @param existing-member The principal to remove from the committee.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (remove-committee-member (existing-member principal))
  (begin
    (try! (assert-is-contract-owner))
    (asserts! (is-committee-member existing-member) ERR-COMMITTEE-MEMBER-NOT-REGISTERED)
    (ok (map-set committee-members existing-member false))
  ))

;; @desc Sets the minimum number of committee approvals required for a milestone.
;; @param num-approvals The new number of required approvals.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (set-required-approvals (num-approvals uint))
  (begin
    (try! (assert-is-contract-owner))
    (asserts! (> num-approvals u0) ERR-CANNOT-SET-ZERO-APPROVALS)
    (var-set required-approvals num-approvals)
    (ok true)
  ))

;; --- Mission Management Functions ---

;; @desc Allows any principal to propose a new space mission.
;; @param mission-name The name of the mission.
;; @param funding-target The total STX target for the mission.
;; @returns `(ok mission-id)` if successful, an error otherwise.
(define-public (propose-mission (mission-name (string-ascii 100)) (funding-target uint))
  (let
    ((new-mission-id (var-get next-mission-id)))
    (asserts! (> funding-target u0) ERR-INVALID-INPUT)
    (asserts! (> (len mission-name) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len mission-name) u100) ERR-MISSION-NAME-TOO-LONG)

    (map-set mission-data new-mission-id {
        mission-name: mission-name,
        proposer: tx-sender,
        total-funding-target: funding-target,
        current-funds-held: u0,
        status: STATUS-PROPOSED
    })
    (var-set next-mission-id (+ new-mission-id u1))
    (ok new-mission-id)
  ))

;; @desc Allows any principal to fund a mission with STX.
;; @param mission-id The ID of the mission to fund.
;; @param amount The amount of STX to contribute.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (fund-mission (mission-id uint) (amount uint))
  (let
    (
      (mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID))
      (current-status (get status mission))
      (current-contribution (default-to u0 (map-get? funder-contributions { mission-id: mission-id, funder: tx-sender })))
    )
    (asserts! (or (is-eq current-status STATUS-PROPOSED) (is-eq current-status STATUS-ACTIVE)) ERR-MISSION-NOT-ACTIVE)
    (asserts! (> amount u0) ERR-INVALID-INPUT)

    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

    ;; Update mission status to Active if first funding
    (if (is-eq current-status STATUS-PROPOSED)
      (map-set mission-data mission-id (merge mission { 
        status: STATUS-ACTIVE,
        current-funds-held: (+ (get current-funds-held mission) amount)
      }))
      (map-set mission-data mission-id (merge mission { 
        current-funds-held: (+ (get current-funds-held mission) amount)
      }))
    )
    
    ;; Record funder contribution
    (map-set funder-contributions { mission-id: mission-id, funder: tx-sender }
      (+ current-contribution amount))
    
    (ok true)
  ))

;; @desc Allows the mission proposer to add a new milestone.
;; @param mission-id The ID of the mission.
;; @param description A description of the milestone.
;; @param amount-to-release The STX amount to release upon milestone completion.
;; @returns `(ok milestone-id)` if successful, an error otherwise.
(define-public (add-milestone (mission-id uint) (description (string-ascii 256)) (amount-to-release uint))
  (let
    (
      (new-milestone-id (var-get next-milestone-id))
      (mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID))
    )
    (try! (assert-is-mission-proposer mission-id))
    (asserts! (not (is-eq (get status mission) STATUS-CANCELED)) ERR-MISSION-ALREADY-CANCELED)
    (asserts! (> amount-to-release u0) ERR-INVALID-INPUT)
    (asserts! (> (len description) u0) ERR-INVALID-INPUT)
    (asserts! (<= (len description) u256) ERR-MILESTONE-DESCRIPTION-TOO-LONG)
    (asserts! (<= amount-to-release (get total-funding-target mission)) ERR-MILESTONE-AMOUNT-EXCEEDS-MISSION-TARGET)

    (map-set milestones new-milestone-id {
        mission-id: mission-id,
        description: description,
        amount-to-release: amount-to-release,
        is-achieved: false,
        is-paid: false
    })
    (var-set next-milestone-id (+ new-milestone-id u1))
    (ok new-milestone-id)
  ))

;; @desc Allows a committee member to approve a milestone as "Achieved".
;; @param milestone-id The ID of the milestone to approve.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (approve-milestone (milestone-id uint))
  (let
    ((milestone (unwrap! (map-get? milestones milestone-id) ERR-INVALID-MILESTONE-ID)))
    (try! (assert-is-committee-member))
    (asserts! (not (get is-achieved milestone)) ERR-MILESTONE-ALREADY-ACHIEVED)
    (asserts! (not (get is-paid milestone)) ERR-MILESTONE-ALREADY-PAID)
    (asserts! (not (default-to false (map-get? milestone-approvals { milestone-id: milestone-id, approver: tx-sender }))) ERR-ALREADY-APPROVED)

    (ok (map-set milestone-approvals { milestone-id: milestone-id, approver: tx-sender } true))
  ))

;; @desc Releases funds for a milestone if enough committee approvals are met.
;; @param milestone-id The ID of the milestone to release funds for.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (release-milestone-funds (milestone-id uint))
  (let
    (
      (milestone (unwrap! (map-get? milestones milestone-id) ERR-INVALID-MILESTONE-ID))
      (mission-id (get mission-id milestone))
      (mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID))
      (approvals (get-num-milestone-approvals milestone-id))
      (proposer (get proposer mission))
      (amount (get amount-to-release milestone))
      (current-funds (get current-funds-held mission))
    )
    (try! (assert-is-mission-proposer mission-id))
    (asserts! (not (is-eq (get status mission) STATUS-CANCELED)) ERR-MISSION-ALREADY-CANCELED)
    (asserts! (not (get is-paid milestone)) ERR-MILESTONE-ALREADY-PAID)
    (asserts! (>= approvals (var-get required-approvals)) ERR-INSUFFICIENT-APPROVERS)
    (asserts! (>= current-funds amount) ERR-INSUFFICIENT-FUNDS)

    ;; Mark milestone as achieved and paid
    (map-set milestones milestone-id (merge milestone { is-achieved: true, is-paid: true }))

    ;; Update mission's funds held
    (map-set mission-data mission-id (merge mission { current-funds-held: (- current-funds amount) }))

    ;; Transfer STX to mission proposer
    (try! (as-contract (stx-transfer? amount tx-sender proposer)))
    (ok true)
  ))

;; @desc Allows the contract owner or committee member to cancel a mission.
;; @param mission-id The ID of the mission to cancel.
;; @returns `(ok true)` if successful, an error otherwise.
(define-public (cancel-mission (mission-id uint))
  (let
    ((mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID)))
    (asserts! (or (is-eq tx-sender (var-get contract-owner)) (is-committee-member tx-sender)) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq (get status mission) STATUS-CANCELED)) ERR-MISSION-ALREADY-CANCELED)

    (map-set mission-data mission-id (merge mission { status: STATUS-CANCELED }))
    (ok true)
  ))

;; @desc Allows a funder to withdraw their contribution from a canceled mission.
;; @param mission-id The ID of the canceled mission.
;; @returns `(ok uint)` the amount refunded, or an error.
(define-public (withdraw-from-canceled-mission (mission-id uint))
  (let
    (
      (mission (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID))
      (funder tx-sender)
      (contribution (default-to u0 (map-get? funder-contributions { mission-id: mission-id, funder: funder })))
      (total-target (get total-funding-target mission))
      (current-funds (get current-funds-held mission))
    )
    (asserts! (is-eq (get status mission) STATUS-CANCELED) ERR-MISSION-NOT-CANCELED)
    (asserts! (> contribution u0) ERR-INSUFFICIENT-FUNDS)
    (asserts! (not (default-to false (map-get? funder-refunds { mission-id: mission-id, funder: funder }))) ERR-REFUND-ALREADY-PROCESSED)

    ;; Calculate proportional refund based on remaining funds
    (let
      ((refund-amount (if (> current-funds u0)
                         (/ (* contribution current-funds) total-target)
                         u0)))
      (asserts! (> refund-amount u0) ERR-INSUFFICIENT-FUNDS)
      
      ;; Mark refund as processed
      (map-set funder-refunds { mission-id: mission-id, funder: funder } true)
      
      ;; Transfer refund
      (try! (as-contract (stx-transfer? refund-amount tx-sender funder)))
      
      ;; Update mission funds
      (map-set mission-data mission-id (merge mission { current-funds-held: (- current-funds refund-amount) }))
      
      (ok refund-amount)
    )))

;; --- Read-Only Functions ---

;; @desc Retrieves the full data for a specific mission.
;; @param mission-id The unique identifier of the mission.
;; @returns `(ok mission-data)` if found, an error otherwise.
(define-read-only (get-mission-details (mission-id uint))
  (ok (unwrap! (map-get? mission-data mission-id) ERR-INVALID-MISSION-ID)))

;; @desc Retrieves the full data for a specific milestone.
;; @param milestone-id The unique identifier of the milestone.
;; @returns `(ok milestone-data)` if found, an error otherwise.
(define-read-only (get-milestone-details (milestone-id uint))
  (ok (unwrap! (map-get? milestones milestone-id) ERR-INVALID-MILESTONE-ID)))

;; @desc Returns the current count of approvals for a milestone.
;; @param milestone-id The ID of the milestone.
;; @returns `(ok uint)` the number of approvals.
(define-read-only (get-milestone-approval-count (milestone-id uint))
  (ok (get-num-milestone-approvals milestone-id)))

;; @desc Checks if a principal is an authorized committee member.
;; @param account The principal to check.
;; @returns `(ok bool)`.
(define-read-only (is-account-committee-member (account principal))
  (ok (is-committee-member account)))

;; @desc Retrieves the currently required number of approvals for milestones.
;; @returns `(ok uint)`.
(define-read-only (get-required-approvals-count)
  (ok (var-get required-approvals)))

;; @desc Retrieves the next available mission ID.
;; @returns `(ok uint)`.
(define-read-only (get-next-mission-id)
  (ok (var-get next-mission-id)))

;; @desc Retrieves the next available milestone ID.
;; @returns `(ok uint)`.
(define-read-only (get-next-milestone-id)
  (ok (var-get next-milestone-id)))

;; @desc Retrieves a funder's total contributions for a specific mission.
;; @param mission-id The ID of the mission.
;; @param funder The principal of the funder.
;; @returns `(ok uint)` the total contributed amount.
(define-read-only (get-funder-contribution (mission-id uint) (funder principal))
  (ok (default-to u0 (map-get? funder-contributions { mission-id: mission-id, funder: funder }))))

;; @desc Checks if a funder has already processed their refund for a canceled mission.
;; @param mission-id The ID of the mission.
;; @param funder The principal of the funder.
;; @returns `(ok bool)`.
(define-read-only (has-funder-refunded (mission-id uint) (funder principal))
  (ok (default-to false (map-get? funder-refunds { mission-id: mission-id, funder: funder }))))

;; @desc Gets the contract owner.
;; @returns `(ok principal)`.
(define-read-only (get-contract-owner)
  (ok (var-get contract-owner)))