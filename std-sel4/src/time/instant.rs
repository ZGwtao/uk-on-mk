// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.

use core::{
    ops::{Add, Sub},
    time::Duration,
};

#[derive(Clone, Copy, Debug, Eq, PartialEq, Ord, PartialOrd)]
pub struct Instant(u64);

impl Instant {
    pub fn now() -> Self {
        Self(sddf_rs::timer_now())
    }

    pub fn elapsed(self) -> Duration {
        Self::now() - self
    }

    pub fn duration_since(self, earlier: Self) -> Duration {
        Duration::from_nanos(self.0.saturating_sub(earlier.0))
    }

    pub fn checked_duration_since(self, earlier: Self) -> Option<Duration> {
        self.0.checked_sub(earlier.0).map(Duration::from_nanos)
    }
}

impl Add<Duration> for Instant {
    type Output = Self;

    fn add(self, duration: Duration) -> Self {
        Self(self.0 + duration.as_nanos() as u64)
    }
}

impl Sub<Duration> for Instant {
    type Output = Self;

    fn sub(self, duration: Duration) -> Self {
        Self(self.0 - duration.as_nanos() as u64)
    }
}

impl Sub<Self> for Instant {
    type Output = Duration;

    fn sub(self, earlier: Self) -> Duration {
        self.duration_since(earlier)
    }
}
