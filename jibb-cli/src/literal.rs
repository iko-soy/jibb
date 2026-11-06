use num_bigint::BigUint;

const OFFSET: i128 = 292_277_024_400;

pub fn ship(text: &str) -> Option<BigUint> {
    urbit_ob::patp2big(text)
        .ok()?
        .to_string()
        .parse::<BigUint>()
        .ok()
}

pub fn format_ship(value: &BigUint) -> Option<String> {
    let value = value.to_string().parse::<ibig::UBig>().ok()?;
    Some(urbit_ob::patp(value))
}

pub fn date(text: &str) -> Option<BigUint> {
    let body = text.strip_prefix('~')?;
    let sections = body.split("..").collect::<Vec<_>>();
    if sections.len() > 3 {
        return None;
    }
    let date = sections[0].split('.').collect::<Vec<_>>();
    if date.len() != 3 {
        return None;
    }
    let bc = date[0].ends_with('-');
    let year_text = date[0].strip_suffix('-').unwrap_or(date[0]);
    let year = year_text.parse::<i128>().ok()?;
    let month = date[1].parse::<i128>().ok()?;
    let day = date[2].parse::<i128>().ok()?;
    let year = if bc {
        OFFSET - (year - 1)
    } else {
        OFFSET + year
    };
    let days = days_from_civil(year, month, day);
    if days < 0 {
        return None;
    }
    let mut seconds = BigUint::from(days as u128) * BigUint::from(86_400u32);
    if sections.len() >= 2 {
        let time = sections[1].split('.').collect::<Vec<_>>();
        if time.len() != 3 {
            return None;
        }
        let hours = time[0].parse::<u64>().ok()?;
        let minutes = time[1].parse::<u64>().ok()?;
        let secs = time[2].parse::<u64>().ok()?;
        seconds += BigUint::from(hours * 3_600 + minutes * 60 + secs);
    }
    let fractions = if sections.len() == 3 {
        parse_fractions(std::slice::from_ref(&sections[2]))?
    } else {
        BigUint::default()
    };
    Some((seconds << 64) | fractions)
}

pub fn format_date(value: &BigUint) -> Option<String> {
    let mut seconds = (value >> 64u32).to_string().parse::<u64>().ok()?;
    let fraction = (value & BigUint::from(u64::MAX))
        .to_string()
        .parse::<u64>()
        .ok()?;
    let days = seconds / 86_400;
    seconds %= 86_400;
    let (year, month, day) = civil_from_days(days);
    let bc = year <= OFFSET;
    let display_year = if bc { OFFSET + 1 - year } else { year - OFFSET };
    let mut result = format!("~{display_year}{}.{month}.{day}", if bc { "-" } else { "" });
    if seconds != 0 || fraction != 0 {
        let hours = seconds / 3_600;
        let minutes = seconds % 3_600 / 60;
        let seconds = seconds % 60;
        result.push_str(&format!("..{hours:02}.{minutes:02}.{seconds:02}"));
        result.push_str(&format_fraction(fraction));
    }
    Some(result)
}

pub fn format_duration(value: &BigUint) -> Option<String> {
    let mut seconds = (value >> 64u32).to_string().parse::<u64>().ok()?;
    let fraction = (value & BigUint::from(u64::MAX))
        .to_string()
        .parse::<u64>()
        .ok()?;
    let days = seconds / 86_400;
    seconds %= 86_400;
    let hours = seconds / 3_600;
    seconds %= 3_600;
    let minutes = seconds / 60;
    seconds %= 60;
    let mut parts = Vec::new();
    if days != 0 {
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

fn civil_from_days(mut days: u64) -> (i128, u64, u64) {
    let era = days / 146_097;
    days %= 146_097;
    let mut year = era as i128 * 400;
    loop {
        let length = if is_leap(year) { 366 } else { 365 };
        if days < length {
            break;
        }
        days -= length;
        year += 1;
    }
    let leap = is_leap(year);
    let lengths = [
        31,
        if leap { 29 } else { 28 },
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ];
    let mut month = 1;
    for length in lengths {
        if days < length {
            break;
        }
        days -= length;
        month += 1;
    }
    (year, month, days + 1)
}

fn is_leap(year: i128) -> bool {
    year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
}

fn format_fraction(value: u64) -> String {
    if value == 0 {
        return String::new();
    }
    let mut groups = (0..4)
        .map(|index| ((value >> (48 - index * 16)) & 0xffff) as u16)
        .collect::<Vec<_>>();
    while groups.last() == Some(&0) {
        groups.pop();
    }
    let first = groups.iter().position(|group| *group != 0).unwrap_or(0);
    let groups = &groups[first..];
    format!(
        "..{}",
        groups
            .iter()
            .map(|group| format!("{group:04x}"))
            .collect::<Vec<_>>()
            .join(".")
    )
}

pub fn duration(text: &str) -> Option<BigUint> {
    let body = text.strip_prefix('~')?;
    let sections = body.split("..").collect::<Vec<_>>();
    if sections.len() > 2 {
        return None;
    }
    let mut seconds = 0u64;
    let mut previous = 0u8;
    for segment in sections[0].split('.') {
        let (unit, number) = segment.split_at(1);
        let number = number.parse::<u64>().ok()?;
        let rank = match unit {
            "d" => 4,
            "h" => 3,
            "m" => 2,
            "s" => 1,
            _ => return None,
        };
        if previous != 0 && rank >= previous {
            return None;
        }
        previous = rank;
        seconds = seconds.checked_add(match unit {
            "d" => number.checked_mul(86_400)?,
            "h" => number.checked_mul(3_600)?,
            "m" => number.checked_mul(60)?,
            "s" => number,
            _ => unreachable!(),
        })?;
    }
    let fractions = if sections.len() == 2 {
        parse_fractions(std::slice::from_ref(&sections[1]))?
    } else {
        BigUint::default()
    };
    Some((BigUint::from(seconds) << 64) | fractions)
}

fn parse_fractions(groups: &[&str]) -> Option<BigUint> {
    if groups.len() > 4 {
        return None;
    }
    let mut value = BigUint::default();
    for group in groups {
        if group.is_empty() || group.len() > 4 {
            return None;
        }
        let group = u16::from_str_radix(group, 16).ok()?;
        value = (value << 16) | BigUint::from(group);
    }
    Some(value)
}

fn days_from_civil(year: i128, month: i128, day: i128) -> i128 {
    let mut days = if year == 0 {
        0
    } else {
        year * 365 + (year - 1) / 4 + 1 - ((year - 1) / 100 + 1) + ((year - 1) / 400 + 1)
    };
    let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0);
    let lengths = [
        31,
        if leap { 29 } else { 28 },
        31,
        30,
        31,
        30,
        31,
        31,
        30,
        31,
        30,
        31,
    ];
    for index in 0..month - 1 {
        days += lengths[index as usize];
    }
    days + day - 1
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn ship_vectors_match_the_reference() {
        assert_eq!(ship("~zod"), Some(BigUint::default()));
        assert_eq!(ship("~binzod"), Some(BigUint::from(512u32)));
        assert_eq!(
            ship("~sampel-palnet"),
            Some(BigUint::from(1_624_961_343u64))
        );
        assert_eq!(
            ship("~mastyr-midwyt-sampel-palnet"),
            Some(BigUint::from(14_598_768_375_314_968_895u64))
        );
        for name in [
            "~zod",
            "~binzod",
            "~sampel-palnet",
            "~mastyr-midwyt-sampel-palnet",
        ] {
            let value = ship(name).unwrap();
            assert_eq!(format_ship(&value).as_deref(), Some(name));
        }
    }

    #[test]
    fn dates_and_durations_use_hoon_seconds_and_fractions() {
        assert_eq!(date("~292277024401-.1.1"), Some(BigUint::default()));
        assert!(date("~1-.1.1").is_some());
        assert_eq!(date("~2026.2.31"), date("~2026.3.3"));
        assert_eq!(duration("~s30"), Some(BigUint::from(30u32) << 64));
        assert_eq!(duration("~h1.m30"), Some(BigUint::from(5_400u32) << 64));
        let with_fraction = duration("~d1000.h5.m30.s12..beef").unwrap();
        let seconds: u64 = 1000 * 86_400 + 5 * 3_600 + 30 * 60 + 12;
        assert_eq!(
            with_fraction,
            (BigUint::from(seconds) << 64) | BigUint::from(0xbeefu32)
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
}
