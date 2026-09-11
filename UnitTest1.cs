using Xunit;

namespace ProductAPI.Tests
{
    public class UnitTest1
    {
        [Fact]
        public void Intentional_Failing_Test_For_Pipeline_Gate_Proof()
        {
            Assert.Equal(1, 2);
        }
    }
}
