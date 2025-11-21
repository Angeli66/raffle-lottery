;; ------------------------------------------------------------
;; Raffle / Lottery Smart Contract
;; Users buy tickets with STX; one winner gets the prize pool.
;; ------------------------------------------------------------

(define-constant ERR_ZERO_AMOUNT        (err u100))
(define-constant ERR_NOT_OPEN           (err u101))
(define-constant ERR_ALREADY_CLOSED     (err u102))
(define-constant ERR_NOT_AUTHORIZED     (err u103))
(define-constant ERR_NO_TICKETS         (err u104))
(define-constant ERR_WINNER_NOT_SET     (err u105))
(define-constant ERR_ALREADY_DRAWN      (err u106))
(define-constant ERR_TRANSFER_FAILED    (err u107))

;; ------------------------------------------------------------
;; Global variables
;; ------------------------------------------------------------
(define-data-var admin principal tx-sender)
(define-data-var raffle-open bool true)
(define-data-var ticket-price uint u1000000) ;; 1 STX = 1_000_000 microSTX
(define-data-var total-tickets uint u0)
(define-data-var total-pool uint u0)
(define-data-var winner (optional principal) none)

;; ------------------------------------------------------------
;; Map of ticket entries (1..n player)
;; ------------------------------------------------------------
(define-map tickets uint principal)

;; ------------------------------------------------------------
;; Public: Buy a raffle ticket
;; ------------------------------------------------------------
(define-public (buy-ticket)
  (begin
    (asserts! (var-get raffle-open) ERR_NOT_OPEN)
    (match (stx-transfer? (var-get ticket-price) tx-sender (as-contract tx-sender))
      success
        (begin
          ;; increment ticket count and save buyer
          (var-set total-tickets (+ (var-get total-tickets) u1))
          (var-set total-pool (+ (var-get total-pool) (var-get ticket-price)))
          (map-set tickets (var-get total-tickets) tx-sender)
          (ok (tuple (ticket-no (var-get total-tickets)) (buyer tx-sender)))
        )
      error ERR_TRANSFER_FAILED
    )
  )
)

;; ------------------------------------------------------------
;; Admin: Close the raffle (stop new entries)
;; ------------------------------------------------------------
(define-public (close-raffle)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (var-get raffle-open) ERR_ALREADY_CLOSED)
    (var-set raffle-open false)
    (ok "Raffle closed. Ready to draw winner.")
  )
)

;; ------------------------------------------------------------
;; Admin: Draw winner (pseudo-random from block height)
;; ------------------------------------------------------------
(define-public (draw-winner)
  (begin
    (asserts! (is-eq tx-sender (var-get admin)) ERR_NOT_AUTHORIZED)
    (asserts! (is-none (var-get winner)) ERR_ALREADY_DRAWN)
    (asserts! (> (var-get total-tickets) u0) ERR_NO_TICKETS)
    (let ((winning-number (+ u1 (mod burn-block-height (var-get total-tickets)))))
      (match (map-get? tickets winning-number)
        player
          (begin
            (var-set winner (some player))
            (ok (tuple (winning-ticket winning-number) (winner player)))
          )
        (err u1)
      )
    )
  )
)

;; ------------------------------------------------------------
;; Admin: Send the prize to the winner
;; ------------------------------------------------------------
(define-public (payout)
  (match (var-get winner)
    winner-principal
      (match (stx-transfer? (var-get total-pool) (as-contract tx-sender) winner-principal)
        success
          (begin
            (var-set total-pool u0)
            (ok (tuple (paid-to winner-principal) (amount (var-get total-pool))))
          )
        error ERR_TRANSFER_FAILED
      )
    ERR_WINNER_NOT_SET
  )
)

;; ------------------------------------------------------------
;; Read-only views
;; ------------------------------------------------------------
(define-read-only (get-ticket (num uint))
  (ok (map-get? tickets num))
)

(define-read-only (get-status)
  (ok (tuple
        (raffle-open (var-get raffle-open))
        (total-tickets (var-get total-tickets))
        (ticket-price (var-get ticket-price))
        (total-pool (var-get total-pool))
        (winner (var-get winner))
      ))
)

(define-read-only (get-admin)
  (ok (var-get admin))
)
