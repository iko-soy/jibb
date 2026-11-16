//! Ship, date and duration literals, read and printed as Hoon reads and prints
//! `@p`, `@da` and `@dr`.
//!
//! Atoms are arbitrary-precision, as in Hoon: a date's year and a duration's
//! counts have no bound. A literal that Hoon's `+year` or `+yule` would crash
//! on, such as month 0 or a day 0, is an error naming the part.

use num_bigint::BigUint;

/// Hoon's year offset: `+year` adds it to an AD year and subtracts the BC year
/// less one, so `~292277024401-.1.1` is the atom 0.
const OFFSET: u64 = 292_277_024_400;
const DAY: u32 = 86_400;

pub fn ship(text: &str) -> Result<BigUint, String> {
    let value = urbit_ob::patp2big(text).map_err(|_| format!("`{text}` is not a valid @p"))?;
    value
        .to_string()
        .parse::<BigUint>()
        .map_err(|_| format!("`{text}` is not a valid @p"))
}

pub fn format_ship(value: &BigUint) -> Option<String> {
    let value = value.to_string().parse::<ibig::UBig>().ok()?;
    Some(urbit_ob::patp(value))
}

/// Reads `~Y.M.D`, `~Y-.M.D`, optionally followed by `..H.M.S` and
/// `..FFFF` groups, as Hoon's `+year` and `+yule` compute it.
pub fn date(text: &str) -> Result<BigUint, String> {
    let invalid = |reason: &str| format!("invalid date literal `{text}`: {reason}");
    let body = text
        .strip_prefix('~')
        .ok_or_else(|| invalid("a date starts with `~`"))?;
    let sections = body.split("..").collect::<Vec<_>>();
    if sections.len() > 3 {
        return Err(invalid("too many `..` sections"));
    }
    let date = sections[0].split('.').collect::<Vec<_>>();
    let [year, month, day] = date.as_slice() else {
        return Err(invalid("a date is a year, a month and a day"));
    };
    let bc = year.ends_with('-');
    let year = decimal(year.strip_suffix('-').unwrap_or(year))
        .ok_or_else(|| invalid("the year is not a decimal number"))?;
    let month = decimal(month).ok_or_else(|| invalid("the month is not a decimal number"))?;
    let day = decimal(day).ok_or_else(|| invalid("the day is not a decimal number"))?;
    // +year: an AD year adds the offset, a BC year subtracts the year less one,
    // and Hoon's `dec` and `sub` crash below zero.
    let year = if bc {
        if is_zero(&year) {
            return Err(invalid("there is no year 0 BC"));
        }
        let before = year - 1u8;
        if before > BigUint::from(OFFSET) {
            return Err(invalid("the year is before Hoon's earliest date"));
        }
        BigUint::from(OFFSET) - before
    } else {
        BigUint::from(OFFSET) + year
    };
    // +yawn asserts a month from 1 to 12 and decrements the day.
    let month = u8::try_from(&month)
        .ok()
        .filter(|month| (1..=12).contains(month))
        .ok_or_else(|| invalid("the month is not from 1 to 12"))?;
    if is_zero(&day) {
        return Err(invalid("the day is 0"));
    }
    let days = days_before_year(&year) + days_before_month(&year, month) + day - 1u8;
    let mut seconds = days * DAY;
    if let Some(time) = sections.get(1) {
        let parts = time.split('.').collect::<Vec<_>>();
        let [hours, minutes, secs] = parts.as_slice() else {
            return Err(invalid("a time is hours, minutes and seconds"));
        };
        let hours = decimal(hours).ok_or_else(|| invalid("the hours are not a number"))?;
        let minutes = decimal(minutes).ok_or_else(|| invalid("the minutes are not a number"))?;
        let secs = decimal(secs).ok_or_else(|| invalid("the seconds are not a number"))?;
        seconds += hours * 3_600u32 + minutes * 60u32 + secs;
    }
    let fraction = match sections.get(2) {
        Some(groups) => fraction(groups).ok_or_else(|| {
            invalid("sub-seconds are one to four groups of four hexadecimal digits")
        })?,
        None => BigUint::default(),
    };
    Ok((seconds << 64u32) | fraction)
}

/// Prints an `@da` as `(scot %da …)` does.
pub fn format_date(value: &BigUint) -> Option<String> {
    let seconds = value >> 64u32;
    let fraction = u64::try_from(&(value & BigUint::from(u64::MAX))).ok()?;
    let days = &seconds / DAY;
    let time = u64::try_from(&(&seconds % DAY)).ok()?;
    let (year, month, day) = civil_from_days(&days);
    let offset = BigUint::from(OFFSET);
    let (display_year, bc) = if year <= offset {
        (offset + 1u8 - &year, true)
    } else {
        (year - offset, false)
    };
    let mut result = format!("~{display_year}{}.{month}.{day}", if bc { "-" } else { "" });
    if time != 0 || fraction != 0 {
        let hours = time / 3_600;
        let minutes = time % 3_600 / 60;
        let seconds = time % 60;
        result.push_str(&format!("..{hours:02}.{minutes:02}.{seconds:02}"));
        result.push_str(&format_fraction(fraction));
    }
    Some(result)
}

/// Prints an `@dr` as `(scot %dr …)` does.
pub fn format_duration(value: &BigUint) -> Option<String> {
    let seconds = value >> 64u32;
    let fraction = u64::try_from(&(value & BigUint::from(u64::MAX))).ok()?;
    let days = &seconds / DAY;
    let rest = u64::try_from(&(&seconds % DAY)).ok()?;
    let hours = rest / 3_600;
    let minutes = rest % 3_600 / 60;
    let seconds = rest % 60;
    let mut parts = Vec::new();
    if !is_zero(&days) {
        parts.push(format!("d{days}"));
    }
    if hours != 0 {
        parts.push(format!("h{hours}"));
    }
    if minutes != 0 {
        parts.push(format!("m{minutes}"));
    }
    if seconds != 0 || parts.is_empty() {
        parts.push(format!("s{seconds}"));
    }
    let mut result = format!("~{}", parts.join("."));
    result.push_str(&format_fraction(fraction));
    Some(result)
}

/// Reads `~d1.h2.m3.s4` with optional `..FFFF` groups, its units in order.
pub fn duration(text: &str) -> Result<BigUint, String> {
    let invalid = |reason: &str| format!("invalid duration literal `{text}`: {reason}");
    let body = text
        .strip_prefix('~')
        .ok_or_else(|| invalid("a duration starts with `~`"))?;
    let sections = body.split("..").collect::<Vec<_>>();
    if sections.len() > 2 {
        return Err(invalid("too many `..` sections"));
    }
    let mut seconds = BigUint::default();
    let mut previous = 0u8;
    for segment in sections[0].split('.') {
        let mut characters = segment.chars();
        let unit = characters.next();
        let (rank, scale) = match unit {
            Some('d') => (4, DAY),
            Some('h') => (3, 3_600),
            Some('m') => (2, 60),
            Some('s') => (1, 1),
            _ => return Err(invalid("a unit is d, h, m or s")),
        };
        if previous != 0 && rank >= previous {
            return Err(invalid("units go from days to seconds, each once"));
        }
        previous = rank;
        let number =
            decimal(characters.as_str()).ok_or_else(|| invalid("a unit takes a number"))?;
        seconds += number * scale;
    }
    let fraction = match sections.get(1) {
        Some(groups) => fraction(groups).ok_or_else(|| {
            invalid("sub-seconds are one to four groups of four hexadecimal digits")
        })?,
        None => BigUint::default(),
    };
    Ok((seconds << 64u32) | fraction)
}

fn is_zero(value: &BigUint) -> bool {
    value.bits() == 0
}

fn decimal(text: &str) -> Option<BigUint> {
    if text.is_empty() || !text.bytes().all(|byte| byte.is_ascii_digit()) {
        return None;
    }
    BigUint::parse_bytes(text.as_bytes(), 10)
}

/// Sub-second groups as `+yule` packs them: the first group is the most
/// significant 16 bits of the 64-bit fraction, so `..8000` is half a second.
fn fraction(groups: &str) -> Option<BigUint> {
    let groups = groups.split('.').collect::<Vec<_>>();
    if groups.is_empty() || groups.len() > 4 {
        return None;
    }
    let mut value = 0u64;
    for (index, group) in groups.iter().enumerate() {
        if group.len() != 4 || !group.bytes().all(|byte| byte.is_ascii_hexdigit()) {
            return None;
        }
        let group = u64::from(u16::from_str_radix(group, 16).ok()?);
        value |= group << (16 * (3 - index));
    }
    Some(BigUint::from(value))
}

/// Sub-second groups as `+yell` unpacks them: from the most significant group
/// down, stopping once the remaining groups are zero, so leading zero groups
/// are kept and trailing ones dropped.
fn format_fraction(value: u64) -> String {
    let mut groups = Vec::new();
    let mut remaining = value;
    let mut index = 4u32;
    while remaining != 0 && index != 0 {
        index -= 1;
        groups.push(format!("{:04x}", (remaining >> (16 * index)) & 0xffff));
        remaining &= (1u64 << (16 * index)).wrapping_sub(1);
    }
    if groups.is_empty() {
        String::new()
    } else {
        format!("..{}", groups.join("."))
    }
}

fn is_leap(year: &BigUint) -> bool {
    let rem = |divisor: u32| is_zero(&(year % divisor));
    rem(4) && (!rem(100) || rem(400))
}

/// Days from Hoon's year 0 to the start of `year`, counting year 0 as a leap
/// year, as `+yawn`'s loop does.
fn days_before_year(year: &BigUint) -> BigUint {
    if is_zero(year) {
        return BigUint::default();
    }
    let before = year - 1u8;
    year * 365u32 + (&before / 4u32 + 1u8) + (&before / 400u32 + 1u8) - (&before / 100u32 + 1u8)
}

fn month_lengths(year: &BigUint) -> [u32; 12] {
    let february = if is_leap(year) { 29 } else { 28 };
    [31, february, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
}

fn days_before_month(year: &BigUint, month: u8) -> BigUint {
    BigUint::from(
        month_lengths(year)[..usize::from(month - 1)]
            .iter()
            .sum::<u32>(),
    )
}

fn civil_from_days(days: &BigUint) -> (BigUint, u32, BigUint) {
    // 146,097 days are 400 Gregorian years.
    let era = days / 146_097u32;
    let mut rest = u32::try_from(&(days % 146_097u32)).unwrap_or_default();
    let mut year = era * 400u32;
    loop {
        let length = if is_leap(&year) { 366 } else { 365 };
        if rest < length {
            break;
        }
        rest -= length;
        year += 1u8;
    }
    let mut month = 1;
    for length in month_lengths(&year) {
        if rest < length {
            break;
        }
        rest -= length;
        month += 1;
    }
    (year, month, BigUint::from(rest) + 1u8)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ship_vectors_match_the_reference() {
        assert_eq!(ship("~zod"), Ok(BigUint::default()));
        assert_eq!(ship("~binzod"), Ok(BigUint::from(512u32)));
        assert_eq!(ship("~sampel-palnet"), Ok(BigUint::from(1_624_961_343u64)));
        assert_eq!(
            ship("~mastyr-midwyt-sampel-palnet"),
            Ok(BigUint::from(14_598_768_375_314_968_895u64))
        );
        for name in [
            "~zod",
            "~binzod",
            "~sampel-palnet",
            "~mastyr-midwyt-sampel-palnet",
            "~rolruc-midwyl-hathes-palsym--fotnul-pagpur-nopful-lomtem",
        ] {
            let value = ship(name).unwrap();
            assert_eq!(format_ship(&value).as_deref(), Some(name));
        }
        assert!(ship("~zzz").is_err());
    }

    #[test]
    fn dates_and_durations_use_hoon_seconds_and_fractions() {
        assert_eq!(date("~292277024401-.1.1"), Ok(BigUint::default()));
        assert!(date("~1-.1.1").is_ok());
        assert_eq!(date("~2026.2.31"), date("~2026.3.3"));
        assert_eq!(duration("~s30"), Ok(BigUint::from(30u32) << 64));
        assert_eq!(duration("~h1.m30"), Ok(BigUint::from(5_400u32) << 64));
        let with_fraction = duration("~d1000.h5.m30.s12..beef").unwrap();
        let seconds: u64 = 1000 * 86_400 + 5 * 3_600 + 30 * 60 + 12;
        assert_eq!(
            with_fraction,
            (BigUint::from(seconds) << 64) | (BigUint::from(0xbeefu32) << 48)
        );
        assert_eq!(
            format_duration(&duration("~s30").unwrap()).as_deref(),
            Some("~s30")
        );
        assert_eq!(
            format_date(&date("~2026.2.31").unwrap()).as_deref(),
            Some("~2026.3.3")
        );
        for text in ["~h1.m30", "~d1000.h5.m30.s12..beef"] {
            assert_eq!(
                format_duration(&duration(text).unwrap()).as_deref(),
                Some(text)
            );
        }
        for text in ["~1-.1.1", "~292277024401-.1.1", "~2026.1.1"] {
            assert_eq!(format_date(&date(text).unwrap()).as_deref(), Some(text));
        }
    }

    #[test]
    fn sub_seconds_fill_the_fraction_from_its_top_bits() {
        // Hoon: (slav %dr '~s0..8000') is 2^63, half a second.
        assert_eq!(duration("~s0..8000"), Ok(BigUint::from(1u8) << 63));
        assert_eq!(
            duration("~s1..0001.0002"),
            Ok((BigUint::from(1u8) << 64)
                | (BigUint::from(1u8) << 48)
                | (BigUint::from(2u8) << 32))
        );
        let half = duration("~s0..8000").unwrap();
        assert_eq!(format_duration(&(&half + &half)).as_deref(), Some("~s1"));
        assert_eq!(
            format_duration(&BigUint::from(1u8)).as_deref(),
            Some("~s0..0000.0000.0000.0001")
        );
        for text in [
            "~s0..8000",
            "~s1..0001.0002",
            "~m1..0000.0001",
            "~2026.1.1..00.00.00..0001.0002",
            "~2026.1.1..12.30.05..8000",
        ] {
            let value = if text.contains("..00.") || text.contains("..12.") {
                format_date(&date(text).unwrap())
            } else {
                format_duration(&duration(text).unwrap())
            };
            assert_eq!(value.as_deref(), Some(text));
        }
    }

    #[test]
    fn invalid_calendar_parts_are_errors() {
        for (text, reason) in [
            ("~2026.0.1", "month"),
            ("~2026.13.1", "month"),
            ("~2026.14.1", "month"),
            ("~2026.99.1", "month"),
            ("~2026.1.0", "day is 0"),
            ("~0-.1.1", "no year 0 BC"),
            ("~292277024402-.1.1", "earliest"),
            ("~2026.1.1..00.00.00..123", "sub-seconds"),
            (
                "~2026.1.1..00.00.00..1234.1234.1234.1234.1234",
                "sub-seconds",
            ),
        ] {
            let error = date(text).unwrap_err();
            assert!(error.contains(reason), "{text}: {error}");
        }
        assert!(duration("~s1.m2").unwrap_err().contains("days to seconds"));
        assert!(duration("~x1").unwrap_err().contains("unit"));
    }

    #[test]
    fn years_and_counts_are_unbounded() {
        let year = "~100000000000000000000000000000000000000.1.1";
        let value = date(year).unwrap();
        assert_eq!(format_date(&value).as_deref(), Some(year));
        let days = "~d99999999999999999999";
        assert_eq!(
            format_duration(&duration(days).unwrap()).as_deref(),
            Some(days)
        );
        assert_eq!(
            format_date(&date("~1.1.1").unwrap()).as_deref(),
            Some("~1.1.1")
        );
        assert_eq!(
            format_date(&date("~2025.12.31").unwrap()).as_deref(),
            Some("~2025.12.31")
        );
    }
}
