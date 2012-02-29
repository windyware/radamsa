;;;
;;; Alignment-based sequence fusing
;;;

(define-library (rad fuse)

   (export fuse)

   (import 
      (owl base))

   (begin

      (define (jump lst from to)
         (if (eq? lst from)
            to
            (cons (car lst)
               (jump (cdr lst) from to))))

      (define (suffixes lst)  
         (if (null? lst)
            null
            (cons lst (suffixes (cdr lst)))))

      (define (char-suffixes sufs)
         (fold
            (λ (subs suf)
               (if (null? suf)
                  subs
                  (put subs (car suf)
                     (cons (cdr suf) (get subs (car suf) null)))))
            #false sufs))

      ;; node = ((suffix ...) . (suffix ...))
      (define (split node tl)
         (lets
            ((sas (char-suffixes (car node)))
             (sbs (char-suffixes (cdr node))))
            (ff-fold
               (λ (tl char sufs) ;; all suffixes in a after prefix+char
                  (let ((bs (getf sbs char)))
                     (if bs ;; there were some also in b
                        (cons (cons sufs bs) tl)
                        tl))) ;; nothing shared
               tl sas)))

      (define (try-choose rs nodes)
         (lets/cc3 ret
            ((rs nodes (random-permutation rs nodes)))
            (fold
               (λ (rs node)
                  (lets 
                     ((rs as (random-permutation rs (car node)))
                      (rs bs (random-permutation rs (cdr node))))
                     (let loop ((as as) (bs bs))
                        (cond
                           ((null? as) rs)
                           ((null? bs) rs)
                           ((equal? (car as) (car bs)) rs) ;; don't jump to the same place
                           (else
                              ;; return via cont
                              (ret rs (car as) (car bs)))))))
               rs nodes)
            ;; if nothig found
            (values rs #false #false)))

      ;; walk in parallel all shared strings of given length
      ; rs nodes prob → rs' a|#f b|#f
      (define (try-pair rs nodes prob)
         (if (null? nodes)
            (values rs #false #false)
            (lets ((rs n (rand rs prob)))
               (if (eq? n 0)
                  (try-choose rs nodes)                   ;; choose a pair out of current nodes
                  (lets
                     ((subs (foldr split null nodes))
                      (rs a b (try-pair rs subs prob)))
                     (if a 
                        (values rs a b)
                        (try-choose rs nodes)))))))      ;; nothing shared below, try here
     
      (define (find-pair rs a b)
         (let ((nodes (list (cons (suffixes a) (suffixes b)))))
            (let loop ((rs rs) (prob 8))
               (lets ((rs a b (try-pair rs nodes prob)))
                  (if a 
                     (values rs a b)
                     (loop rs (>> prob 1))))))) ;; always terminates immediately if 1

      (define (fuse rs al bl)
         (lets ((rs a b (find-pair rs al bl)))
            (values rs (jump al a b))))

      ;(lets ((rs l (fuse (seed->rands (time-ms)) '(1 2 3 a b c 4) '(5 6 a b c 7 8 9))))
      ;   (print l))
))
