package pipeline

@Test
func addPositive(): Unit {
    @Expect(add(2, 3), 5)
    @Expect(add(0, 0), 0)
    @Expect(add(-1, 1), 0)
}

@Test
func addNegative(): Unit {
    @Expect(add(-5, -7), -12)
}

@Test
func subtractBasic(): Unit {
    @Expect(subtract(10, 4), 6)
    @Expect(subtract(0, 0), 0)
    @Expect(subtract(-3, -3), 0)
}

@Test
func multiplyBasic(): Unit {
    @Expect(multiply(3, 4), 12)
    @Expect(multiply(-2, 5), -10)
    @Expect(multiply(0, 99), 0)
}

@Test
func addCommutative(): Unit {
    @Expect(add(7, 11), add(11, 7))
    @Expect(add(-4, 9), add(9, -4))
}
