package com.harvestglass.harvest.util

import kotlin.math.roundToInt

/** Port of Harvest/Utilities/HeightFormatter.swift. */
object HeightFormatter {

    fun feetAndInches(centimeters: Int): Pair<Int, Int> {
        val totalInches = (centimeters / 2.54).roundToInt()
        return totalInches / 12 to totalInches % 12
    }

    fun string(centimeters: Int): String {
        val (feet, inches) = feetAndInches(centimeters)
        return "$feet'$inches\""
    }
}
