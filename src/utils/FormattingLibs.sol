// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.26;

import {Strings} from "@openzeppelin-v5/contracts/utils/Strings.sol";

using Strings for uint256;

/// @notice Shared formatter for scaled integer amounts (e.g. 18-decimal wei to "1.5").
function formatScaledAmount(uint256 amount, uint8 exponent, uint8 maxDecimals) pure returns (string memory) {
    if (exponent > maxDecimals) {
        uint256 factor = 10 ** (exponent - maxDecimals);
        uint256 half = factor / 2;
        // avoid overflow for very large amounts
        amount = amount <= type(uint256).max - half ? (amount + half) / factor : amount / factor;
    }
    uint256 intPart = amount / 10 ** maxDecimals;
    uint256 fracPart = amount % 10 ** maxDecimals;
    string memory intString = intPart.toString();
    if (fracPart == 0) return intString;
    string memory fracString = fracPart.toString();
    while (bytes(fracString).length < maxDecimals) {
        fracString = string.concat("0", fracString);
    }
    return string.concat(intString, ".", fracString);
}

library FlowRateFormatter {
    using Strings for uint256;

    enum Period {
        SECOND,
        MINUTE,
        HOUR,
        DAY,
        WEEK,
        MONTH,
        YEAR
    }

    error InvalidPeriod();

    function getSecondsInPeriod(Period period) private pure returns (uint256) {
        if (period == Period.SECOND) return 1;
        if (period == Period.MINUTE) return 60;
        if (period == Period.HOUR) return 3600;
        if (period == Period.DAY) return 86400;
        if (period == Period.WEEK) return 604800;
        if (period == Period.MONTH) return 2628000;
        if (period == Period.YEAR) return 31536000;
        revert InvalidPeriod();
    }

    function toDailyFlowRateString(int96 flowRate) internal pure returns (string memory) {
        return toFlowRateString(flowRate, Period.DAY, 5);
    }

    function toFlowRateString(int96 flowRate, Period period, uint8 maxDecimals) internal pure returns (string memory) {
        int256 absFlowRate = (flowRate < 0) ? -flowRate : flowRate;
        uint256 tokensPerPeriod = uint256(absFlowRate) * getSecondsInPeriod(period);
        string memory frAbs = formatScaledAmount(tokensPerPeriod, 18, maxDecimals);
        return (flowRate < 0) ? string.concat("-", frAbs) : frAbs;
    }
}

library AmountFormatter {
    /// @notice Format a raw token amount (18 decimals) for display.
    function formatTokenAmount(uint256 amount, uint8 maxDecimals) internal pure returns (string memory) {
        return formatScaledAmount(amount, 18, maxDecimals);
    }
}

/// @notice Formats a Unix timestamp as "YYYY-mm-dd hh:mm UTC" (deterministic, no state).
/// Uses the date conversion algorithm from BokkyPooBah's DateTime Library (MIT).
/// https://github.com/bokkypoobah/BokkyPooBahsDateTimeLibrary
library DateTimeFormatter {
    using Strings for uint256;

    uint256 private constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint256 private constant SECONDS_PER_HOUR = 60 * 60;
    uint256 private constant SECONDS_PER_MINUTE = 60;
    int256 private constant OFFSET19700101 = 2440588;

    /// @notice Returns a deterministic date-time string for the given timestamp, e.g. "2026-02-11 14:30 UTC".
    function formatTimestampUtc(uint256 timestamp) internal pure returns (string memory) {
        (uint256 year, uint256 month, uint256 day) = _daysToDate(timestamp / SECONDS_PER_DAY);
        uint256 secs = timestamp % SECONDS_PER_DAY;
        uint256 hour = secs / SECONDS_PER_HOUR;
        secs = secs % SECONDS_PER_HOUR;
        uint256 minute = secs / SECONDS_PER_MINUTE;

        return string.concat(
            year.toString(),
            "-",
            _pad2(month),
            "-",
            _pad2(day),
            " ",
            _pad2(hour),
            ":",
            _pad2(minute),
            " UTC"
        );
    }

    /// @dev Days since 1970/01/01 to year/month/day. From BokkyPooBah's DateTime Library.
    function _daysToDate(uint256 _days) private pure returns (uint256 year, uint256 month, uint256 day) {
        int256 __days = int256(_days);
        int256 L = __days + 68569 + OFFSET19700101;
        int256 N = 4 * L / 146097;
        L = L - (146097 * N + 3) / 4;
        int256 _year = 4000 * (L + 1) / 1461001;
        L = L - 1461 * _year / 4 + 31;
        int256 _month = 80 * L / 2447;
        int256 _day = L - 2447 * _month / 80;
        L = _month / 11;
        _month = _month + 2 - 12 * L;
        _year = 100 * (N - 49) + _year + L;

        year = uint256(_year);
        month = uint256(_month);
        day = uint256(_day);
    }

    function _pad2(uint256 n) private pure returns (string memory) {
        if (n < 10) return string.concat("0", n.toString());
        return n.toString();
    }
}
