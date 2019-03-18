library(tidyverse)
library(jsonlite)
library(lubridate)

globals <- read_json("data/global.json")
tids <- globals$vocabularies %>%
  map_dfr(~tibble(tid = .x$tid, name = .x$name, type = .x$v_name,
                  parent = .x$parent))
journalism_tids <- filter(tids, parent == "257")
year_tids <- filter(tids, type == "Years") %>%
  select(tid, prize_year = name)

parse_works <- function(work) {
  title <- work$item$field_title_of_work$und[[1]]$safe_value
  if (is.null(title)) title <- NA
  # content <- work$item$field_work_detail$und[[1]]$safe_value
  # if (is.null(content)) content <- NA
  published <- work$item$field_date$und[[1]]$value %>% ymd_hms
  if (is.null(published) | length(published) == 0) published <- NA
  tibble(title, published, .rows = 1)
}

parse_winner <- function(raw) {
  location <- raw$field_location_text$und[[1]]$safe_value
  if (is.null(location)) location <- NA
  abbr_citation <- raw$field_abbr_citation$und[[1]]$safe_value
  if (is.null(abbr_citation)) abbr_citation <- NA
  tibble(title = raw$title,
         nid = raw$nid,
         type = raw$type,
         category_id = raw$field_category$und[[1]]$tid,
         year_id = raw$field_year$und[[1]]$tid,
         abbr_citation,
         location,
         works = raw$field_list_of_works$und %>% map_dfr(parse_works) %>% list,
         .rows = 1)
}

raw <- 2000:2018 %>%
  map_dfr(function(year) {
    filename <- str_glue("ppt/data/winners-", year, ".json")
    read_json(filename) %>%
      map(parse_json) %>%
      map_dfr(parse_winner)
  }) %>%
  rename(tid = category_id) %>%
  select(-type) %>%
  inner_join(journalism_tids, by = "tid") %>%
  select(-c(tid, parent)) %>%
  rename(tid = year_id) %>%
  left_join(year_tids, by = "tid") %>%
  select(-tid) %>%
  mutate(prize_year = parse_number(prize_year))

raw %>% write_rds("data/winners_2000-2018.rds")

raw %>%
  unnest %>%
  filter(year(published) == prize_year - 1) %>%
  ggplot(aes(yday(published))) +
    geom_histogram() +
    facet_wrap(vars(prize_year), scales = "free_x")
