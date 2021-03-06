
test_that("can slice", {
  dt <- lazy_dt(data.table(x = 1, y = 2), "DT")

  expect_equal(
    dt %>% slice() %>% show_query(),
    expr(DT)
  )
  expect_equal(
    dt %>% slice(1:4) %>% show_query(),
    expr(DT[1:4])
  )
  expect_equal(
    dt %>% slice(1, 2, 3) %>% show_query(),
    expr(DT[c(1, 2, 3)])
  )
})

test_that("can slice when grouped", {
  dt1 <- lazy_dt(data.table(x = c(1, 1, 2, 2), y = c(1, 2, 3, 4)), "DT")
  dt2 <- dt1 %>% group_by(x) %>% slice(1)

  expect_equal(
    dt2 %>% show_query(),
    expr(DT[DT[, .I[1], by = .(x)]$V1])
  )
  expect_equal(as_tibble(dt2), tibble(x = c(1, 2), y = c(1, 3)))
})

test_that("slicing doesn't sorts groups", {
  dt <- lazy_dt(data.table(x = 2:1))
  expect_equal(
    dt %>% group_by(x) %>% slice(1) %>% pull(x),
    2:1
  )
})

# variants ----------------------------------------------------------------

test_that("functions silently truncate results", {
  dt <- lazy_dt(data.frame(x = 1:5))

  expect_equal(dt %>% slice_head(n = 6) %>% as_tibble() %>% nrow(), 5)
  expect_equal(dt %>% slice_tail(n = 6) %>% as_tibble() %>% nrow(), 5)
  expect_equal(dt %>% slice_sample(n = 6) %>% as_tibble() %>% nrow(), 5)
  expect_equal(dt %>% slice_min(x, n = 6) %>% as_tibble() %>% nrow(), 5)
  expect_equal(dt %>% slice_max(x, n = 6) %>% as_tibble() %>% nrow(), 5)
})

test_that("proportion rounds down", {
  dt <- lazy_dt(data.frame(x = 1:10))

  expect_equal(dt %>% slice_head(prop = 0.11) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_tail(prop = 0.11) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_sample(prop = 0.11) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_min(x, prop = 0.11) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_max(x, prop = 0.11) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_min(x, prop = 0.11, with_ties = FALSE) %>% as_tibble() %>% nrow(), 1)
  expect_equal(dt %>% slice_max(x, prop = 0.11, with_ties = FALSE) %>% as_tibble() %>% nrow(), 1)
})

test_that("min and max return ties by default", {
  dt <- lazy_dt(data.frame(x = c(1, 1, 1, 2, 2)))
  expect_equal(dt %>% slice_min(x) %>% collect() %>% nrow(), 3)
  expect_equal(dt %>% slice_max(x) %>% collect() %>% nrow(), 2)

  expect_equal(dt %>% slice_min(x, with_ties = FALSE) %>% collect() %>%  nrow(), 1)
  expect_equal(dt %>% slice_max(x, with_ties = FALSE) %>% collect() %>% nrow(), 1)
})

test_that("min and max reorder results", {
  dt <- lazy_dt(data.frame(id = 1:4, x = c(2, 3, 1, 2)))

  expect_equal(dt %>% slice_min(x, n = 2) %>% pull(id), c(3, 1, 4))
  expect_equal(dt %>% slice_min(x, n = 2, with_ties = FALSE) %>% pull(id), c(3, 1))
  expect_equal(dt %>% slice_max(x, n = 2) %>% pull(id), c(2, 1, 4))
  expect_equal(dt %>% slice_max(x, n = 2, with_ties = FALSE) %>% pull(id), c(2, 1))
})

test_that("min and max ignore NA's (#4826)", {
  dt <- lazy_dt(data.frame(id = 1:4, x = c(2, NA, 1, 2), y = c(NA, NA, NA, NA)))

  expect_equal(dt %>% slice_min(x, n = 2) %>% pull(id), c(3, 1, 4))
  expect_equal(dt %>% slice_min(y, n = 2) %>% pull(id), integer())
  expect_equal(dt %>% slice_max(x, n = 2) %>% pull(id), c(1, 4))
  expect_equal(dt %>% slice_max(y, n = 2) %>% pull(id), integer())
})

test_that("arguments to sample are passed along", {
  dt <- lazy_dt(data.frame(x = 1:100, wt = c(1, rep(0, 99))))

  expect_equal(dt %>% slice_sample(n = 1, weight_by = wt) %>% pull(x), 1)
  expect_equal(dt %>% slice_sample(n = 2, weight_by = wt, replace = TRUE) %>% pull(x), c(1, 1))
})

test_that("slice_*() checks for empty ...", {
  dt <- lazy_dt(data.frame(x = 1:10))
  expect_error(slice_head(dt, 5), "not empty")
  expect_error(slice_tail(dt, 5), "not empty")
  expect_error(slice_min(dt, x, 5), "not empty")
  expect_error(slice_max(dt, x, 5), "not empty")
  expect_error(slice_sample(dt, 5), "not empty")

  expect_error(slice_min(dt), "missing")
  expect_error(slice_max(dt), "missing")
})

test_that("check_slice_catches common errors", {
  expect_snapshot(error = TRUE, {
    check_slice_size(n = 1, prop = 1)
    check_slice_size(n = "a")
    check_slice_size(prop = "a")
    check_slice_size(n = -1)
    check_slice_size(prop = -1)
  })
})


# sample ------------------------------------------------------------------

test_that("basic usage generates expected calls", {
  dt <- lazy_dt(data.table(x = 1:5, y = 1), "DT")

  expect_equal(
    dt %>% sample_n(3) %>% show_query(),
    expr(DT[sample(.N, 3)])
  )
  expect_equal(
    dt %>% sample_frac(0.5) %>% show_query(),
    expr(DT[sample(.N, .N * 0.5)])
  )

  expect_equal(
    dt %>% sample_n(3, replace = TRUE) %>% show_query(),
    expr(DT[sample(.N, 3, replace = TRUE)])
  )
  expect_equal(
    dt %>% sample_n(3, weight = y) %>% show_query(),
    expr(DT[sample(.N, 3, prob = y)])
  )
})
