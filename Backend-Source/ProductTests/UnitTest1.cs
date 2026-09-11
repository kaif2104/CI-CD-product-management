namespace ProductTests;

public class UnitTest1
{
    [Fact]
    public void Test1()
    {
        // Intentionally failing test to demonstrate CI/CD pipeline stopping deployment
        Assert.True(false, "Intentional test failure for Phase 2 proof");
    }
}
