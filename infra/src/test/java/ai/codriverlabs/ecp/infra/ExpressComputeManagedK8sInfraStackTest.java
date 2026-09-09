package ai.codriverlabs.ecp.infra;

import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import software.amazon.awscdk.App;
import software.amazon.awscdk.StackProps;
import software.amazon.awscdk.assertions.Capture;
import software.amazon.awscdk.assertions.Match;
import software.amazon.awscdk.assertions.Template;

import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;

class ExpressComputeManagedK8sInfraStackTest {

    private static Template template;

    @BeforeAll
    static void synth() {
        var app = new App(software.amazon.awscdk.AppProps.builder()
                .context(Map.of(
                        "projectName", "ecp-managed-k8s-infra"
                ))
                .build());

        var stack = new ai.codriverlabs.ecp.ExpressComputeManagedK8sInfraStack(
                app, "TestStack", StackProps.builder().build());

        template = Template.fromStack(stack);
    }

    @Nested
    @DisplayName("CloudFormation Parameters")
    class Parameters {

        @Test
        void definesAllExpectedParameters() {
            template.hasParameter("ProjectName", Map.of("Type", "String"));
            template.hasParameter("InstanceTypeArm64", Map.of("Type", "String"));
            template.hasParameter("InstanceTypeX86", Map.of("Type", "String"));
            template.hasParameter("DiskSizeGb", Map.of("Type", "Number"));
            template.hasParameter("Region", Map.of("Type", "String"));
            template.hasParameter("EnableNatGateway", Map.of(
                    "Type", "String",
                    "AllowedValues", java.util.List.of("true", "false")
            ));
            // k3s-Xpress parameters
            template.hasParameter("K3sInstanceTypeArm64", Map.of("Type", "String"));
            template.hasParameter("K3sInstanceTypeX86", Map.of("Type", "String"));
            template.hasParameter("K3sDiskSizeGb", Map.of("Type", "Number"));
            template.hasParameter("K3sDataDiskSizeGb", Map.of("Type", "Number"));
        }
    }

    @Nested
    @DisplayName("VPC Networking")
    class Networking {

        @Test
        void createsVpcWithCorrectCidr() {
            template.hasResourceProperties("AWS::EC2::VPC", Map.of(
                    "CidrBlock", "10.0.0.0/16",
                    "EnableDnsHostnames", true,
                    "EnableDnsSupport", true
            ));
        }

        @Test
        void createsInternetGateway() {
            template.resourceCountIs("AWS::EC2::InternetGateway", 1);
        }

        @Test
        void attachesIgwToVpc() {
            template.resourceCountIs("AWS::EC2::VPCGatewayAttachment", 1);
        }

        @Test
        void createsNatSubnetWithCorrectCidr() {
            template.hasResourceProperties("AWS::EC2::Subnet", Map.of(
                    "CidrBlock", "10.0.0.0/24",
                    "MapPublicIpOnLaunch", true
            ));
        }

        @Test
        void createsTwoRouteTables() {
            template.resourceCountIs("AWS::EC2::RouteTable", 2);
        }

        @Test
        void createsNatGatewayWithCondition() {
            var resources = template.findResources("AWS::EC2::NatGateway");
            assertThat(resources).hasSize(1);
            var natGw = resources.values().iterator().next();
            @SuppressWarnings("unchecked")
            var condition = ((Map<String, Object>) natGw).get("Condition");
            assertThat(condition).isNotNull();
        }

        @Test
        void createsElasticIpWithCondition() {
            var resources = template.findResources("AWS::EC2::EIP");
            assertThat(resources).hasSize(1);
            var eip = resources.values().iterator().next();
            @SuppressWarnings("unchecked")
            var condition = ((Map<String, Object>) eip).get("Condition");
            assertThat(condition).isNotNull();
        }

        @Test
        void publicRouteTableHasDefaultRouteToIgw() {
            template.hasResourceProperties("AWS::EC2::Route", Map.of(
                    "DestinationCidrBlock", "0.0.0.0/0",
                    "GatewayId", Match.anyValue()
            ));
        }
    }

    @Nested
    @DisplayName("VPC Flow Logs")
    class FlowLogs {

        @Test
        void createsFlowLog() {
            template.hasResourceProperties("AWS::EC2::FlowLog", Map.of(
                    "ResourceType", "VPC",
                    "TrafficType", "ALL",
                    "LogDestinationType", "cloud-watch-logs"
            ));
        }

        @Test
        void createsLogGroupWithOneWeekRetention() {
            template.hasResourceProperties("AWS::Logs::LogGroup", Map.of(
                    "RetentionInDays", 7
            ));
        }

        @Test
        void createsFlowLogsIamRole() {
            template.hasResourceProperties("AWS::IAM::Role", Map.of(
                    "AssumeRolePolicyDocument", Match.objectLike(Map.of(
                            "Statement", Match.arrayWith(java.util.List.of(
                                    Match.objectLike(Map.of(
                                            "Principal", Map.of(
                                                    "Service", "vpc-flow-logs.amazonaws.com"
                                            )
                                    ))
                            ))
                    ))
            ));
        }
    }

    @Nested
    @DisplayName("ECR Pull-Through Cache")
    class EcrCache {

        @Test
        void createsThreePullThroughCacheRules() {
            template.resourceCountIs("AWS::ECR::PullThroughCacheRule", 3);
        }

        @Test
        void cachesPublicEcr() {
            template.hasResourceProperties("AWS::ECR::PullThroughCacheRule", Map.of(
                    "EcrRepositoryPrefix", "public-ecr",
                    "UpstreamRegistryUrl", "public.ecr.aws"
            ));
        }

        @Test
        void cachesRegistryK8sIo() {
            template.hasResourceProperties("AWS::ECR::PullThroughCacheRule", Map.of(
                    "EcrRepositoryPrefix", "registry-k8s-io",
                    "UpstreamRegistryUrl", "registry.k8s.io"
            ));
        }

        @Test
        void cachesQuayIo() {
            template.hasResourceProperties("AWS::ECR::PullThroughCacheRule", Map.of(
                    "EcrRepositoryPrefix", "quay-io",
                    "UpstreamRegistryUrl", "quay.io"
            ));
        }
    }

    @Nested
    @DisplayName("S3 Gateway Endpoint")
    class S3Endpoint {

        @Test
        void createsS3GatewayEndpoint() {
            template.hasResourceProperties("AWS::EC2::VPCEndpoint", Map.of(
                    "VpcEndpointType", "Gateway"
            ));
        }

        @Test
        void endpointAttachesToBothRouteTables() {
            var capture = new Capture();
            template.hasResourceProperties("AWS::EC2::VPCEndpoint", Map.of(
                    "RouteTableIds", capture
            ));
            var routeTableIds = capture.asArray();
            assertThat(routeTableIds).hasSize(2);
        }
    }

    @Nested
    @DisplayName("Launch Templates")
    class LaunchTemplates {

        @Test
        void createsEightLaunchTemplates() {
            // 4 EKS-D + 4 k3s = 8 total
            template.resourceCountIs("AWS::EC2::LaunchTemplate", 8);
        }

        @Test
        void allTemplatesRequireImdsV2() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var metadata = (Map<String, Object>) ltData.get("MetadataOptions");
                assertThat(metadata.get("HttpTokens")).isEqualTo("required");
            }
        }

        @Test
        void allTemplatesHaveTwoBlockDevices() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var blockDevices = (java.util.List<?>) ltData.get("BlockDeviceMappings");
                assertThat(blockDevices).hasSize(2);
            }
        }

        @Test
        void allEbsVolumesAreEncrypted() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var blockDevices = (java.util.List<Map<String, Object>>) ltData.get("BlockDeviceMappings");
                for (var bd : blockDevices) {
                    @SuppressWarnings("unchecked")
                    var ebs = (Map<String, Object>) bd.get("Ebs");
                    assertThat(ebs.get("Encrypted")).isEqualTo(true);
                }
            }
        }

        @Test
        void allEbsVolumesAreGp3() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var blockDevices = (java.util.List<Map<String, Object>>) ltData.get("BlockDeviceMappings");
                for (var bd : blockDevices) {
                    @SuppressWarnings("unchecked")
                    var ebs = (Map<String, Object>) bd.get("Ebs");
                    assertThat(ebs.get("VolumeType")).isEqualTo("gp3");
                }
            }
        }

        @Test
        void spotTemplatesUsePersistentWithHibernation() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            int spotCount = 0;
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var marketOptions = (Map<String, Object>) ltData.get("InstanceMarketOptions");
                if (marketOptions != null) {
                    spotCount++;
                    assertThat(marketOptions.get("MarketType")).isEqualTo("spot");
                    @SuppressWarnings("unchecked")
                    var spotOptions = (Map<String, Object>) marketOptions.get("SpotOptions");
                    assertThat(spotOptions.get("SpotInstanceType")).isEqualTo("persistent");
                    assertThat(spotOptions.get("InstanceInterruptionBehavior")).isEqualTo("hibernate");

                    @SuppressWarnings("unchecked")
                    var hibernation = (Map<String, Object>) ltData.get("HibernationOptions");
                    assertThat(hibernation.get("Configured")).isEqualTo(true);
                }
            }
            assertThat(spotCount).isEqualTo(4); // 2 EKS-D + 2 k3s
        }

        @Test
        void onDemandTemplatesHaveNoMarketOptions() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            int onDemandCount = 0;
            for (var entry : resources.entrySet()) {
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                var marketOptions = ltData.get("InstanceMarketOptions");
                if (marketOptions == null) {
                    onDemandCount++;
                }
            }
            assertThat(onDemandCount).isEqualTo(4); // 2 EKS-D + 2 k3s
        }
    }

    @Nested
    @DisplayName("SSM Parameters")
    class SsmParameters {

        @Test
        void createsTenSsmParameters() {
            // 4 EKS-D LT + 4 k3s LT + vpc-id + nat-gateway-enabled = 10
            template.resourceCountIs("AWS::SSM::Parameter", 10);
        }

        @Test
        void publishesVpcId() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/network/vpc-id"
            ));
        }

        @Test
        void publishesNatGatewayEnabled() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/network/nat-gateway-enabled"
            ));
        }

        @Test
        void publishesArm64SpotLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/arm64/spot"
            ));
        }

        @Test
        void publishesArm64OndemandLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/arm64/ondemand"
            ));
        }

        @Test
        void publishesX86SpotLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/x86_64/spot"
            ));
        }

        @Test
        void publishesX86OndemandLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/x86_64/ondemand"
            ));
        }

        @Test
        void publishesK3sArm64SpotLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/k3s/arm64/spot"
            ));
        }

        @Test
        void publishesK3sArm64OndemandLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/k3s/arm64/ondemand"
            ));
        }

        @Test
        void publishesK3sX86SpotLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/k3s/x86_64/spot"
            ));
        }

        @Test
        void publishesK3sX86OndemandLaunchTemplate() {
            template.hasResourceProperties("AWS::SSM::Parameter", Map.of(
                    "Name", "/express-compute/infra/launch-template/k3s/x86_64/ondemand"
            ));
        }
    }

    @Nested
    @DisplayName("k3s-Xpress Launch Templates")
    class K3sLaunchTemplates {

        @Test
        void k3sTemplatesHaveDistributionTag() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            int k3sCount = 0;
            for (var entry : resources.entrySet()) {
                if (!entry.getKey().startsWith("K3sLt")) continue;
                k3sCount++;
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var tagSpecs = (java.util.List<Map<String, Object>>) props.get("TagSpecifications");
                boolean hasDistributionTag = tagSpecs.stream()
                        .flatMap(ts -> ((java.util.List<Map<String, Object>>) ts.get("Tags")).stream())
                        .anyMatch(t -> "Distribution".equals(t.get("Key")) && "k3s".equals(t.get("Value")));
                assertThat(hasDistributionTag)
                        .as("k3s LT %s should have Distribution=k3s tag", entry.getKey())
                        .isTrue();
            }
            assertThat(k3sCount).isEqualTo(4);
        }

        @Test
        void k3sTemplatesHaveK3sPlatformTag() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                if (!entry.getKey().startsWith("K3sLt")) continue;
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var instanceTagSpecs = (java.util.List<Map<String, Object>>) ltData.get("TagSpecifications");
                boolean hasPlatformTag = instanceTagSpecs.stream()
                        .filter(ts -> "instance".equals(ts.get("ResourceType")))
                        .flatMap(ts -> ((java.util.List<Map<String, Object>>) ts.get("Tags")).stream())
                        .anyMatch(t -> "Platform".equals(t.get("Key")) && "k3s-xpress".equals(t.get("Value")));
                assertThat(hasPlatformTag)
                        .as("k3s LT %s instance tags should have Platform=k3s-xpress", entry.getKey())
                        .isTrue();
            }
        }

        @Test
        void k3sTemplatesRequireImdsV2() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                if (!entry.getKey().startsWith("K3sLt")) continue;
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var metadata = (Map<String, Object>) ltData.get("MetadataOptions");
                assertThat(metadata.get("HttpTokens")).isEqualTo("required");
            }
        }

        @Test
        void k3sTemplatesHaveTwoEncryptedGp3Volumes() {
            var resources = template.findResources("AWS::EC2::LaunchTemplate");
            for (var entry : resources.entrySet()) {
                if (!entry.getKey().startsWith("K3sLt")) continue;
                @SuppressWarnings("unchecked")
                var props = (Map<String, Object>) ((Map<String, Object>) entry.getValue()).get("Properties");
                @SuppressWarnings("unchecked")
                var ltData = (Map<String, Object>) props.get("LaunchTemplateData");
                @SuppressWarnings("unchecked")
                var blockDevices = (java.util.List<Map<String, Object>>) ltData.get("BlockDeviceMappings");
                assertThat(blockDevices).hasSize(2);
                for (var bd : blockDevices) {
                    @SuppressWarnings("unchecked")
                    var ebs = (Map<String, Object>) bd.get("Ebs");
                    assertThat(ebs.get("VolumeType")).isEqualTo("gp3");
                    assertThat(ebs.get("Encrypted")).isEqualTo(true);
                }
            }
        }
    }

    @Nested
    @DisplayName("Conditions")
    class Conditions {

        @Test
        void definesNatEnabledCondition() {
            template.hasCondition("NatEnabled", Match.anyValue());
        }
    }
}
