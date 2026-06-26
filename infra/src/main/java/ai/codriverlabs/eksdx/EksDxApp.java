package ai.codriverlabs.eksdx;

import software.amazon.awscdk.App;
import software.amazon.awscdk.Environment;
import software.amazon.awscdk.StackProps;

public class EksDxApp {
    public static void main(String[] args) {
        App app = new App();

        // Account from environment; region intentionally omitted so the
        // pre-synthesized cdk.out uses unknown-region and deploys to any region
        // at runtime via --region / AWS_REGION.
        var env = Environment.builder()
                .account(System.getenv("CDK_DEFAULT_ACCOUNT"))
                .build();

        new SharedInfraStack(app, "EksDxSharedInfraStack", StackProps.builder()
                .env(env).build());

        app.synth();
    }
}
