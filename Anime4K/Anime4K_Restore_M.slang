// Anime4K Restore CNN (Medium)
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex1;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex1_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex2;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex2_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex3;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex3_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex4;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex4_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex5;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex5_UAV;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
Texture2D tex6;

[bgfx::SIZE("INPUT_WIDTH", "INPUT_HEIGHT")]
[format("rgba16f")]
RWTexture2D<float4> tex6_UAV;

[bgfx::EFFECT("Anime4K Restore M", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("CNN-based image restoration filter for anime content. Medium variant balances quality and performance.")]
[bgfx::FP16]
[bgfx::PASS(1, "Feature Extraction Conv-4x3x3x3")]
[bgfx::PASS_IO("INPUT", "tex1_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass1(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half3 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(INPUT.GatherRed(sam, tpos));
            const half4 sg = half4(INPUT.GatherGreen(sam, tpos));
            const half4 sb = half4(INPUT.GatherBlue(sam, tpos));

            src[i][j] = half3(sr.w, sg.w, sb.w);
            src[i][j + 1] = half3(sr.x, sg.x, sb.x);
            src[i + 1][j] = half3(sr.z, sg.z, sb.z);
            src[i + 1][j + 1] = half3(sr.y, sg.y, sb.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.061233472h, 0.39222646h, 0.029704979h, 0.02586828h);
                result = MulAdd(src[i - 1][j - 1], half3x4(-0.09991986h, 0.13782342h, -0.031251684h, -0.06356843h, -0.3437488h, 0.05450952h, 0.34347802h, 0.46335372h, 0.08607224h, 0.044988394h, 0.137179h, 0.17976908h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.024212424h, -0.09278509h, -0.00040907756h, 0.34552294h, -0.13254678h, 0.113105185h, 0.005667946h, -0.00036919137h, -0.06375679h, 0.009184115h, 0.115518734h, -0.115506776h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.14101827h, 0.023523493h, 0.044094566h, -0.019271746h, -0.44348842h, -0.08818877h, -0.4026149h, -0.21995795h, -0.15880394h, -0.013732858h, -0.020751135h, 0.012719151h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.013001821h, -0.34503505h, 0.39219138h, 0.18792126h, 0.24760444h, -0.016173402h, 0.10154511h, 0.15453082h, -0.058132876h, 0.016784398h, -0.05808539h, -0.11039915h), result);
                result = MulAdd(src[i][j], half3x4(0.37024534h, 0.041440863h, -0.3374568h, -0.44994286h, 0.19555596h, 0.20855539h, -0.27974075h, -0.5372628h, 0.21228147h, -0.0295346h, -0.56700057h, 0.030042822h), result);
                result = MulAdd(src[i][j + 1], half3x4(-0.12940632h, 0.057526h, 0.090682045h, -0.06985033h, -0.13704006h, -0.047685407h, 0.44615674h, -0.48056605h, -0.06166251h, -0.01883519h, 0.2032237h, -0.11328760h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(0.010856669h, -0.35820737h, 0.16757219h, 0.082619876h, -0.03967303h, 0.038705572h, 0.32652855h, -0.012030017h, 0.015120559h, -0.15314877h, 0.23442009h, 0.09767922h), result);
                result = MulAdd(src[i + 1][j], half3x4(-0.046272673h, -0.17752305h, 0.082018286h, -0.2512824h, 0.58619463h, -0.060903464h, -0.022793597h, 0.077803515h, -0.17025311h, 0.05136993h, 0.029383298h, -0.15475409h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(-0.11212024h, 0.13378005h, -0.2027488h, 0.08056421h, -0.11176219h, -0.048429377h, -0.08396386h, 0.10507829h, 0.13326839h, 0.0430627h, 0.051362377h, 0.06482755h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(2, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex1", "tex2_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass2(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex1.GatherRed(sam, tpos));
            const half4 sg = half4(tex1.GatherGreen(sam, tpos));
            const half4 sb = half4(tex1.GatherBlue(sam, tpos));
            const half4 sa = half4(tex1.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.018297346h, -0.080951825h, -0.062163066h, -0.08050014h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.16410656h, -0.40521824h, 0.13121907h, -0.02314597h, 0.105412476h, -0.060401272h, -0.043063477h, -0.13933973h, 0.12558138h, -0.020861467h, 0.030370515h, 0.13178016h, -0.14220351h, 0.20736893h, 0.003321564h, -0.29241714h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.18517321h, 0.29162985h, -0.26783395h, 0.039760686h, 0.025527012h, -0.067319244h, 0.055004176h, 0.048916563h, 0.12750523h, -0.091435954h, 0.13818842h, 0.36704224h, 0.0839921h, 0.10186618h, -0.17237376h, 0.13282418h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.1657887h, 0.0131325135h, -0.17222486h, 0.091398895h, -0.12756164h, -0.08437298h, -0.29052997h, 0.3269337h, 0.15870757h, -0.013529402h, -0.0581753h, 0.11802371h, 0.07099966h, -0.024063632h, 0.31834844h, -0.11183859h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.46036887h, -0.07654623h, 0.22923063h, 0.17463821h, 0.10555414h, -0.117430426h, 0.12406777h, -0.011399492h, 0.028316498h, 0.13684341h, 0.009664087h, 0.2022659h, 0.04953974h, -0.31342217h, -0.6103131h, -0.13605757h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.03406955h, -0.39819366h, 0.61176h, -0.46809456h, -0.029321073h, 0.46619493h, 0.36700186h, 0.02288561h, 0.11464085h, -0.10931452h, -0.09154022h, 0.07334147h, -0.5609916h, 0.31826234h, -0.011012659h, -0.46719545h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.056855045h, 0.27037027h, -0.09269696h, -0.563572h, -0.06816116h, -0.22986612h, 0.08693167h, -0.16246101h, 0.09954046h, -0.05374176h, 0.0071916827h, -0.1788692h, 0.3825241h, -0.1609887h, 0.055204768h, 0.10213068h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.0646626h, 0.102358796h, -0.45055822h, 0.20557903h, -0.23337309h, 0.12633002h, -0.19299199h, -0.15085731h, -0.13473304h, 0.053790465h, -0.10061193h, -0.13393497h, -0.04264752h, -0.029740738h, -0.07865285h, 0.20883279h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.010471527h, -0.033218473h, -0.46157447h, 0.004866583h, 0.23226471h, -0.059343327h, -0.1439596h, 0.13619648h, 0.013839963h, 0.15930325h, 0.043742355h, 0.17467323h, 0.33772305h, 0.40261495h, -0.08351293h, 0.18129359h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.12493434h, -0.1875134h, -0.074943796h, -0.0031701606h, -0.037142616h, 0.1667002h, 0.16665547h, -0.011248127h, 0.0071619414h, 0.0034872112h, 0.120318964h, -0.09625579h, 0.14917047h, -0.16310586h, 0.07231737h, 0.30447328h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.093798615h, 0.17074613h, -0.08780678h, -0.012520207h, 0.118534856h, 0.027508778h, -0.2778478h, -0.19509242h, -0.34137097h, 0.32000312h, -0.22027159h, 0.337515h, 0.16220862h, 0.108993016h, 0.14070526h, 0.12784284h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.14325632h, -0.1467453h, -0.27502358h, 0.09370837h, 0.11821083h, -0.012266484h, -0.2100548h, 0.4707502h, -0.06766648h, 0.58165014h, -0.2512279h, -0.33783755h, 0.1318925h, -0.04346277h, 0.15454485h, 0.044500057h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.05683207h, 0.0051946463h, -0.108000524h, 0.10133204h, -0.50763863h, 0.007308442h, 0.8542404h, 0.28387356h, 0.022709515h, 0.294523h, -0.3822472h, 0.66166407h, 0.01404485h, 0.031282708h, -0.26756814h, -0.123147786h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.36455178h, 0.3470555h, -0.045303088h, -0.03170764h, -0.15802494h, -0.0019141496h, -0.25939587h, -0.23875342h, 0.130428h, 0.03954273h, -0.17985536h, 0.105145946h, 0.15804817h, 0.12551713h, 0.28371975h, -0.085748516h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.0060625463h, 0.2443924h, -0.017692259h, -0.20214005h, -0.09584515h, -0.012805372h, -0.13942227h, 0.16143198h, 0.12942013h, 0.41785547h, 0.046071563h, 0.7030026h, 0.10499644h, -0.20566013h, -0.031321276h, 0.27830327h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.081274964h, -0.14562319h, 0.27200526h, -0.20491314h, 0.012910989h, 0.024201397h, 0.04816258h, 0.21297328h, -0.22015952h, -0.44160756h, -0.056035373h, 0.33824417h, -0.31645304h, 0.15469243h, 0.053187452h, -0.20989445h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.046550367h, 0.033185404h, 0.33337244h, 0.12853645h, 0.23520172h, -0.05909214h, 0.0861368h, 0.10706329h, -0.07058717h, -0.11759937h, -0.18594047h, 0.080006264h, -0.055425353h, -0.12506317h, 0.15729053h, -0.0915004h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.042516407h, 0.14844789h, 0.16533111h, 0.13502933h, -0.0655417h, -0.057256397h, 0.076713726h, -0.23448966h, 0.12855926h, 0.014219275h, 0.051761385h, 0.053433083h, -0.2446715h, -0.4008074h, 0.19603717h, -0.1796951h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.14777803h, 0.15524907h, 0.043158617h, -0.06996876h, 0.19210646h, -0.2144364h, -0.47020787h, -0.4207906h, -0.18074386h, -0.2163903h, 0.0030754965h, 0.36799973h, -0.3837698h, -0.0022661497h, -0.37276733h, -0.28934997h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex2", "tex3_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex2.GatherRed(sam, tpos));
            const half4 sg = half4(tex2.GatherGreen(sam, tpos));
            const half4 sb = half4(tex2.GatherBlue(sam, tpos));
            const half4 sa = half4(tex2.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.008952847h, -0.0058945753h, -0.08097229h, 0.020968592h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.31543177h, 0.23095237h, -0.06692611h, -0.5867763h, 0.003622504h, 0.17948842h, -0.14627707h, 0.1745016h, -0.052964583h, -0.15551159h, 0.05644786h, -0.012665164h, 0.13107763h, 0.11369179h, -0.09452995h, -0.11973403h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.2694661h, -0.115382135h, 0.3073268h, -0.067228466h, -0.25511482h, -0.13922207h, 0.36758214h, -0.18821828h, -0.022617863h, 0.20333402h, -0.11125889h, 0.3552245h, -0.013346653h, -0.099095374h, -0.25100616h, 0.35521755h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(0.011012409h, -0.13675085h, 0.25642h, -0.34851208h, -0.23184675h, 0.18012202h, 0.57654136h, 0.103173524h, -0.16461405h, 0.038177088h, 0.1234096h, 0.013202029h, -0.19033363h, 0.07469178h, -0.017948546h, 0.15287702h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.05340533h, 0.23797482h, 0.20351392h, -0.05333351h, -0.12181174h, -0.23363493h, -0.20696607h, 0.109941036h, -0.11519453h, 0.13842066h, -0.10687832h, 0.29040006h, 0.022218632h, 0.031238724h, 0.2685182h, 0.15300068h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.22985318h, -0.3103802h, -0.22916415h, 0.25238806h, -0.11690287h, -0.1947488h, 0.118020535h, 0.07814263h, -0.06335474h, -0.007870727h, 0.076106325h, 0.094677486h, -0.16776285h, -0.006570437h, -0.29589584h, 0.41413507h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.43607962h, -0.36456433h, -0.123776875h, -0.16634953h, -0.091190875h, 0.13035081h, 0.28627968h, 0.27249968h, 0.12356344h, -0.008616177h, 0.09599816h, -0.006144557h, -0.23490307h, 0.3013123h, 0.14153156h, 0.21837278h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.060364585h, 0.37860224h, 0.039182413h, -0.22805426h, -0.089910224h, -0.06817697h, -0.2684275h, -0.12528503h, 0.036934495h, -0.07826616h, 0.06559976h, -0.08253646h, 0.13489649h, 0.06237663h, 0.126376h, 0.21194184h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.12534817h, 0.21225189h, -0.27818045h, -0.3070443h, -0.006957577h, -0.025105853h, 0.12100924h, -0.06916452h, 0.23081483h, 0.1802756h, -0.18995638h, 0.16603014h, -0.2904096h, -0.25292823h, -0.21834068h, 0.13719653h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.017209655h, 0.10757137h, 0.21414296h, -0.30885983h, 0.10467716h, -0.2184891h, 0.100061476h, -0.1527528h, 0.2100472h, -0.25768545h, -0.22329919h, -0.29153427h, -0.06983842h, -0.103854865h, -0.051384352h, 0.14629121h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.0059623295h, -0.26060802h, 0.32115817h, 0.021025505h, 0.09783085h, -0.15865178h, 0.1473021h, -0.24977303h, -0.033508282h, 0.17480391h, -0.091310136h, 0.09870876h, 0.10504043h, -0.06105686h, 0.013493489h, -0.11278855h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.14875248h, -0.14859414h, 0.19377062h, -0.17456068h, 0.101288855h, -0.1113682h, -0.48944646h, 0.1018565h, -0.037392337h, 0.08539691h, 0.1751306h, -0.15428723h, -0.059375558h, 0.027663672h, 0.051804014h, -0.049813222h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.118846565h, -0.19869871h, -0.037388258h, 0.08456728h, -0.11662527h, -0.43818352h, -0.093285345h, 0.038507205h, -0.051991668h, 0.21008292h, 0.10792365h, 0.2020924h, 0.057021596h, 0.09460527h, 0.0016551288h, -0.0015957063h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.11062174h, -0.2639232h, -0.060295466h, -0.3217331h, -0.050545212h, 0.30989558h, 0.30906132h, 0.030323273h, 0.028986752h, 0.037429404h, 0.20855664h, -0.19848943h, 0.034687653h, -0.09599135h, -0.06250494h, -0.13215867h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.010391146h, 0.07657845h, 0.44491258h, 0.0435906h, 0.0075931503h, 0.42632654h, 0.47022533h, 0.34737435h, -0.15452717h, -0.14613411h, -0.45231065h, 0.12094409h, 0.0067911847h, 0.057501152h, 0.09876979h, 0.044946447h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.15607435h, 0.2293058h, -0.09520331h, 0.012836732h, -0.15282455h, 0.26437718h, -0.1685477h, -0.13211122h, -0.055801593h, -0.016778728h, -0.34478986h, -0.23228309h, 0.12300962h, -0.13235827h, -0.13987203h, -0.16550972h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.13161735h, -0.09039346h, -0.033475474h, -0.23686698h, 0.1514885h, 0.20977421h, 0.031431954h, -0.0049226107h, 0.090661936h, 0.15288061h, -0.03316583h, 0.09646573h, -0.32651708h, 0.18825398h, -0.15777239h, 0.17572704h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.112157226h, -0.08712878h, 0.23453182h, 0.1043877h, -0.14686783h, 0.28682423h, -0.086443506h, 0.059457052h, -0.31530112h, -0.2700583h, -0.06028952h, -0.070416875h, 0.18053482h, 0.16653341h, 0.25215197h, 0.061915852h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.20122242h, 0.076313145h, -0.0988483h, 0.094337784h, -0.35436687h, 0.3762327h, -0.07809558h, 0.3055848h, 0.10425242h, -0.17087407h, 0.030301496h, -0.13911743h, 0.01630275h, 0.24247427h, -0.006474477h, 0.03842641h), result);

                tex3_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex3", "tex4_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex3.GatherRed(sam, tpos));
            const half4 sg = half4(tex3.GatherGreen(sam, tpos));
            const half4 sb = half4(tex3.GatherBlue(sam, tpos));
            const half4 sa = half4(tex3.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.059377354h, -0.02055341h, 0.07234869h, -0.015452986h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.2237721h, -0.0064096362h, -0.31808427h, 0.73477733h, 0.015353088h, 0.23983319h, 0.14967978h, -0.34920225h, -0.07456269h, 0.093151815h, -0.14331086h, -0.24586205h, -0.14183366h, 0.06401045h, -0.22044073h, 0.29932275h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.07968509h, -0.3349146h, 0.16529128h, 0.08443499h, 0.4095855h, -0.17120704h, 0.17425705h, 0.15298946h, 0.2981273h, 0.2212369h, 0.10392389h, -0.28775454h, -0.065247655h, -0.15255849h, 0.13094437h, 0.18685219h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(0.015706737h, -0.17755036h, 0.2622526h, 0.112057306h, -0.15876788h, -0.38466996h, -0.33700845h, -0.031711742h, -0.023320962h, -0.3145249h, -0.21223734h, -0.1314596h, -0.1888095h, -0.046370104h, 0.09000896h, -0.0046378844h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.31127506h, 0.31304324h, -0.03965752h, 0.03649018h, -0.029851055h, 0.05801377h, 0.00040150844h, -0.04422069h, 0.18019931h, 0.14415511h, -0.09845236h, 0.21895434h, -0.013932474h, -0.046454947h, -0.3403935h, -0.006705289h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.34878647h, -0.5129283h, 0.060250953h, -0.16354133h, 0.20644619h, 0.08732273h, -0.24118888h, 0.24455065h, 0.24449423h, 0.44103387h, 0.22455928h, 0.25738943h, -0.26914698h, -0.21309987h, 0.08386486h, 0.021484816h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.057454903h, -0.4121922h, 0.022661546h, 0.37178272h, 0.03331408h, 0.05044008h, 0.04324371h, 0.20727943h, 0.2432641h, 0.076906696h, -0.20858039h, 0.012439015h, -0.19335061h, 0.09217451h, 0.1968369h, -0.19435833h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.16960496h, 0.24616167h, 0.37977478h, 0.14324574h, -0.011531225h, -0.11312143h, -0.18141079h, -0.23843932h, 0.0086012175h, -0.3564491h, -0.12639481h, 0.009799298h, -0.29120612h, 0.23756824h, 0.18035695h, -0.087133996h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.10081239h, 0.29191494h, 0.10434693h, 0.08970636h, 0.008997759h, 0.104756236h, 0.039641086h, 0.02323888h, -0.11627765h, 0.023693223h, -0.30801758h, -0.120208986h, 0.05086147h, 0.18498175h, 0.15595439h, -0.09877306h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.101321675h, -0.2929976h, 0.38810417h, 0.5605376h, -0.04073937h, 0.030110704h, -0.18147062h, -0.09833952h, 0.01927733h, 0.15335669h, -0.15384074h, -0.110595055h, -0.054297395h, -0.077522054h, 0.07918369h, -0.068480626h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.23263514h, -0.11719232h, 0.2903209h, -0.007503795h, -0.020222448h, -0.17790157h, -0.15600762h, -0.08741775h, 0.12529704h, 0.25548857h, -0.04585447h, -0.10255033h, 0.18350503h, -0.29593533h, 0.0868933h, 0.027004737h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.14958654h, -0.006238835h, -0.2928948h, 0.1988557h, -0.17057803h, 0.12524141h, 0.13978264h, -0.019280292h, 0.05967142h, -0.07790818h, -0.5893818h, -0.022845713h, -0.08596779h, 0.07875358h, -0.03316667h, -0.4369282h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.19195688h, -0.060883682h, -0.25897828h, 0.07063324h, 0.090833396h, 0.003422883h, 0.109534174h, 0.031180874h, -0.05017118h, 0.022862168h, -0.270113h, -0.057831235h, 0.53920543h, -0.10252776h, -0.091807485h, 0.004294343h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.18494242h, -0.119284816h, 0.3821897h, 0.07777979h, 0.15568028h, -0.2854859h, -0.22441281h, -0.049155876h, -0.15292497h, 0.21895619h, -0.095677756h, 0.15210424h, 0.001643022h, -0.026176987h, 0.048463076h, -0.4824009h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.007215129h, 0.17074333h, 0.053930074h, -0.027014816h, -0.17180431h, -0.15163863h, -0.0012122132h, -0.18934256h, -0.08294297h, -0.24580221h, -0.46552867h, -0.27923223h, 0.4092668h, 0.06288688h, -0.1602188h, -0.0030876845h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(0.111870885h, 0.03317145h, 0.14155298h, 0.20328505h, -0.05104131h, 0.13979794h, 0.018966835h, -0.07238511h, 0.05493792h, -0.14975783h, -0.10293237h, -0.21985306h, 0.49054706h, 0.18288186h, -0.26925826h, 0.35845932h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.3747799h, -0.096748486h, -0.17139742h, 0.25289854h, -0.17421168h, -0.018461818h, 0.09747162h, 0.01660535h, -0.20580359h, 0.56189656h, 0.17151354h, -0.26347768h, 0.28350568h, -0.21486014h, -0.44330928h, -0.008981037h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.10169985h, -0.18244018h, 0.04760736h, 0.41017643h, -0.09468786h, -0.024218475h, 0.103733875h, -0.22540338h, 0.10630112h, 0.3677178h, -0.104170956h, 0.057317447h, 0.21764882h, 0.0789158h, -0.22041337h, 0.15065216h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.11633995h, -0.008195114h, -0.14501533h, 0.07168025h, 0.058413275h, 0.055995367h, 0.09362145h, -0.13827963h, 0.13760869h, 0.040319785h, 0.038895044h, 0.2675253h, -0.087339684h, 0.1412073h, -0.17166458h, -0.2312994h), result);

                tex4_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(5, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex4", "tex5_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass5(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex4.GatherRed(sam, tpos));
            const half4 sg = half4(tex4.GatherGreen(sam, tpos));
            const half4 sb = half4(tex4.GatherBlue(sam, tpos));
            const half4 sa = half4(tex4.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(-0.048888464h, -0.0561434h, 0.030690912h, -0.030496685h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.29012984h, -0.13150147h, 0.31015614h, 0.05992291h, -0.050289866h, 0.14845313h, -0.09608898h, 0.27913308h, 0.060307387h, -0.04160452h, 0.035932682h, -0.08137563h, -0.07999419h, 0.11818284h, -0.27512288h, 0.21948813h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.12916058h, -0.21759962h, -0.33868533h, 0.021636661h, 0.053470243h, 0.1412425h, 0.043395396h, -0.26751056h, -0.01689101h, -0.2623835h, 0.010809152h, 0.062962815h, -0.20692012h, -0.1677863h, -0.23313859h, -0.17402615h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.08204112h, -0.23672083h, -0.0064437394h, -0.13200696h, -0.056692924h, -0.02708657h, 0.12536962h, 0.004428919h, 0.14137582h, 0.15404348h, -0.105753876h, 0.047957454h, 0.15734316h, 0.16562423h, -0.010160829h, -0.06602983h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.025653997h, -0.10877775h, -0.31258908h, 0.18841636h, -0.36005193h, 0.1816357h, -0.34537643h, -0.0741087h, 0.4663994h, 0.0065186517h, 0.08109033h, 0.2976773h, -0.35774228h, -0.041366056h, -0.37852773h, 0.050565656h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.04392313h, 0.11316681h, -0.14421389h, 0.17985669h, -0.1651274h, -0.5656209h, -0.124100484h, 0.42774054h, -0.1153939h, 0.16829851h, 0.2025612h, 0.054007456h, -0.06868256h, -0.56935954h, -0.12227961h, 0.17688861h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.34041h, 0.499h, 0.15234196h, 0.21353458h, -0.2732667h, -0.049950935h, 0.03550811h, -0.21051687h, 0.2609023h, 0.016438454h, -0.29874632h, 0.37994128h, 0.049288407h, -0.31126305h, 0.029235512h, -0.012256015h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.0046853204h, 0.15391374h, -0.040689662h, 0.20186873h, -0.08137621h, 0.35905558h, 0.23733845h, 0.21794793h, -0.066420384h, 0.029600656h, -0.31421044h, -0.050773863h, -0.06260773h, 0.04634221h, -0.10948491h, -0.045498934h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.082953h, -0.025837064h, -0.09928303h, -0.14300232h, 0.275064h, 0.07793617h, 0.22240888h, 0.06637834h, -0.4382666h, -0.2932182h, -0.27243167h, -0.14221182h, 0.5695728h, 0.20719238h, 0.5575927h, 0.40816882h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.18510929h, -0.15052167h, 0.25277212h, 0.06804461h, 0.016387h, 0.20310035h, 0.2903229h, -0.0615877h, -0.28987274h, -0.11942605h, 0.013498961h, 0.3184152h, 0.29543474h, -0.042830903h, -0.018111207h, -0.13263674h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.25749087h, 0.0053866603h, -0.09391162h, -0.06129529h, -0.094091184h, -0.07419633h, 0.0013858611h, 0.012000353h, -0.062903h, -0.0204224h, -0.12113313h, 0.017942557h, -0.073379934h, 0.052201986h, 0.35864577h, 0.023564404h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.100115694h, 0.19451359h, 0.23252094h, 0.19506809h, -0.12470779h, 0.0027281935h, -0.17488572h, -0.018721964h, -0.15159339h, 0.18457152h, 0.057712987h, -0.08191495h, 0.19735703h, 0.07326743h, -0.28563106h, 0.01642815h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.068062514h, 0.28356665h, 0.07377898h, 0.42776972h, 0.28725025h, -0.13045293h, -0.17525704h, -0.05885591h, -0.16676305h, -0.2555945h, -0.10078422h, -0.053032875h, 0.084470876h, 0.06460686h, 0.13824362h, -0.05231353h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.22637829h, -0.028969254h, 0.1968254h, -0.13331996h, 0.038017053h, -0.008854481h, -0.2031639h, 0.09237089h, -0.3821112h, 0.1108527h, -0.11029933h, -0.24542028h, 0.22416145h, -0.031492114h, -0.19144306h, -0.0996271h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.10776744h, 0.16363445h, 0.14656505h, -0.3737814h, -0.06642015h, 0.5616549h, -0.008412252h, -0.37266847h, 0.12506576h, -0.15329036h, 0.037538245h, -0.10810259h, 0.01706349h, 0.1813702h, 0.035651788h, -0.012786579h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.4023338h, -0.2098614h, -0.18285121h, -0.02727653h, 0.26107362h, 0.041306913h, -0.036515504h, -0.045217298h, -0.39958602h, -0.21229339h, -0.021053292h, -0.13427502h, 0.36178818h, 0.20934913h, 0.1500852h, 0.2634554h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.07794611h, -0.25937587h, -0.06822529h, -0.056336135h, 0.094220124h, 0.21588847h, -0.0455218h, -0.10968329h, -0.08068449h, -0.31366697h, 0.07799637h, 0.24252681h, 0.23963861h, 0.13715535h, 0.010329345h, 0.09094301h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.20975718h, -0.12550138h, 0.14453574h, -0.0020878632h, -0.07153068h, 0.3249998h, -0.056577377h, 0.18166828h, 0.37204072h, 0.17018336h, 0.3752895h, 0.32178587h, 0.2571982h, -0.27258632h, -0.25971004h, -0.40536007h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.3243907h, -0.06300621h, -0.09398436h, -0.19549188h, 0.14906861h, 0.061537784h, -0.055284478h, 0.11281728h, 0.12964857h, 0.09979093h, -0.1810159h, -0.4104283h, 0.05807971h, -0.056371246h, 0.08072554h, 0.18479007h), result);

                tex5_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(6, "Feature Processing Conv-4x3x3x8")]
[bgfx::PASS_IO("tex5", "tex6_UAV")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass6(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;
    uint2 inputSize = GetInputSize();
    if (gxy.x >= inputSize.x || gxy.y >= inputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();

    half4 src[4][4];
    $for(ii in Range(0, 2))
    {
        $for(jj in Range(0, 2))
        {
            uint i = ii * 2;
            uint j = jj * 2;
            float2 tpos = (gxy + uint2(i, j)) * inputPt;
            const half4 sr = half4(tex5.GatherRed(sam, tpos));
            const half4 sg = half4(tex5.GatherGreen(sam, tpos));
            const half4 sb = half4(tex5.GatherBlue(sam, tpos));
            const half4 sa = half4(tex5.GatherAlpha(sam, tpos));

            src[i][j] = half4(sr.w, sg.w, sb.w, sa.w);
            src[i][j + 1] = half4(sr.x, sg.x, sb.x, sa.x);
            src[i + 1][j] = half4(sr.z, sg.z, sb.z, sa.z);
            src[i + 1][j + 1] = half4(sr.y, sg.y, sb.y, sa.y);
        }
    }

    $for(i in Range(1, 3))
    {
        $for(j in Range(1, 3))
        {
            uint2 destPos = gxy + uint2(i - 1, j - 1);

            bool shouldProcess = true;
            if (i != 1 || j != 1)
            {
                if (destPos.x >= inputSize.x || destPos.y >= inputSize.y)
                {
                    shouldProcess = false;
                }
            }

            if (shouldProcess)
            {
                half4 result = half4(0.011169491h, 0.032399546h, 0.138099h, 0.023857072h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.15332128h, 0.027258258h, 0.14900503h, -0.15982795h, 0.17021236h, -0.51046044h, -0.15287271h, -0.058167327h, 0.51826185h, -0.34817994h, 0.004513167h, 0.05395769h, 0.1990321h, -0.049979225h, 0.11391989h, -0.16062729h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.033682905h, 0.019728886h, 0.19931756h, 0.17381927h, 0.2585768h, -0.2124572h, -0.014632459h, 0.39779893h, -0.1146207h, -0.2396625h, 0.08960277h, 0.38345298h, 0.25497693h, 0.11692859h, -0.14207517h, 0.12667973h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.14911255h, 0.08910706h, 0.16136818h, 0.03914566h, 0.24204038h, -0.03607149h, -0.4571109h, 0.10802461h, -0.0021356856h, 0.00885878h, 0.22297303h, 0.2367231h, 0.045177583h, 0.11120606h, -0.009971904h, -0.059262395h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(0.24565999h, -0.2261384h, 0.47373205h, 0.024613412h, -0.10923052h, 0.039027315h, -0.42707404h, -0.3783373h, 0.3544573h, -0.5468578h, -0.27599156h, -0.09455918h, 0.18760219h, -0.19082001h, 0.030565469h, 0.20589156h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.1973198h, -0.03433863h, 0.059960485h, 0.045642868h, 0.1819595h, -0.14460869h, 0.1286175h, 0.2067575h, -0.042632047h, -0.11842967h, -0.11224446h, -0.18764776h, -0.19563004h, 0.027425969h, 0.24056377h, 0.5949649h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.055027682h, 0.16331595h, -0.2608588h, 0.12545955h, 0.4588985h, 0.03642909h, 0.22187738h, 0.45190734h, -0.001210133h, -0.057651415h, -0.061199043h, 0.11935476h, -0.049561135h, 0.27509886h, 0.13778673h, -0.124914035h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.02257459h, 0.27705106h, 0.044165276h, -0.26521233h, 0.05982374h, -0.2824302h, 0.3171142h, 0.08430561h, -0.10155528h, 0.16182268h, -0.09183147h, -0.19447176h, 0.3295707h, -0.50616395h, -0.036964044h, 0.23166709h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(-0.0232342h, 0.07299799h, -0.18038079h, -0.13672702h, -0.108305976h, 0.15024792h, -0.19531927h, 0.0870979h, -0.26488534h, 0.19481428h, 0.10737945h, -0.14573483h, -0.33094683h, 0.24155116h, -0.09850332h, 0.2797003h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.24089853h, 0.19506595h, 0.4799156h, -0.058313113h, 0.36212957h, -0.44844806h, 0.23864488h, 0.15477742h, -0.07795971h, -0.0033861927h, -0.11216164h, 0.033454563h, -0.25893036h, 0.23793478h, -0.15769425h, -0.00033481256h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(0.05772507h, -0.1640253h, -0.13499664h, -0.20460358h, -0.024399966h, 0.14966168h, -0.090857334h, -0.039677754h, 0.00036956606h, -0.24236615h, -0.053542696h, -0.0049544116h, 0.026651502h, 0.39019194h, -0.2742246h, -0.061242323h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.016323274h, -0.036179908h, 0.029965919h, 0.11151491h, -0.00016685206h, -0.29573023h, 0.17996423h, -0.20145437h, 0.1324275h, -0.18442132h, -0.24618152h, 0.061780427h, -0.02770517h, 0.28452995h, 0.39804098h, -0.1174389h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.025068847h, -0.053328387h, -0.27053785h, 0.26866457h, -0.09866204h, 0.057677213h, 0.01850112h, -0.18014707h, -0.13319959h, -0.14411181h, -0.26355243h, -0.022209354h, -0.05062645h, -0.036771543h, 0.13294417h, -0.18458557h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.046194963h, 0.038230438h, -0.08993043h, -0.07236354h, 0.11031123h, -0.16504908h, -0.09517036h, -0.16459833h, -0.5279925h, 0.12686682h, -0.05726125h, 0.055361677h, 0.31593755h, 0.027328093h, 0.001839602h, 0.30581662h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.08608678h, 0.03168437h, 0.007713377h, -0.26140293h, -0.1268983h, 0.13395861h, -0.069848835h, -0.24080403h, 0.018839337h, -0.049821075h, -0.21461345h, -0.14168301h, -0.0872339h, 0.47096667h, 0.022512507h, 0.14860632h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(0.06293673h, 0.22462969h, 0.045494985h, 0.021673543h, 0.18227446h, -0.2956555h, 0.08010543h, -0.01919729h, -0.012190269h, 0.241983h, -0.046537094h, -0.40094566h, -0.3853647h, 0.1081711h, -0.16926058h, 0.16138376h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.14854589h, -0.17625804h, -0.10849075h, 0.221543h, 0.099971965h, 0.13901573h, 0.29464146h, 0.020068526h, 0.054358527h, -0.10351705h, -0.0062914286h, 0.24127026h, -0.16914125h, 0.12729423h, -0.18377453h, -0.6452375h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(0.12603393h, -0.10986093h, 0.2314103h, 0.16915044h, -0.13619255h, -0.09349073h, 0.20594226h, -0.34507084h, 0.19077192h, 0.052500796h, 0.07185645h, 0.029082738h, -0.015576321h, 0.08254907h, -0.5501743h, -0.38495848h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(0.09300796h, -0.079218306h, 0.46825135h, -0.08735625h, 0.06321122h, 0.16234867h, 0.042932414h, -0.013057422h, 0.09697148h, 0.23457524h, 0.19417483h, -0.16804664h, 0.18379296h, 0.17770062h, -0.050235h, -0.059676602h), result);

                tex6_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(7, "Reconstruction Conv-4x3x3x8, Conv-3x1x1x56")]
[bgfx::PASS_IO("INPUT, tex1, tex2, tex3, tex4, tex5, tex6", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass7(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 pos = (gxy + 0.5f) * inputPt;

    half4 a = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, -inputPt.y), 0));
    half4 b = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex6.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex6.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex6.SampleLevel(sam, pos, 0));
    half4 f = half4(tex6.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex6.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 src1 = half4(tex1.SampleLevel(sam, pos, 0));
    half4 src2 = half4(tex2.SampleLevel(sam, pos, 0));
    half4 src3 = half4(tex3.SampleLevel(sam, pos, 0));
    half4 src4 = half4(tex4.SampleLevel(sam, pos, 0));
    half4 src5 = half4(tex5.SampleLevel(sam, pos, 0));
    half4 src6 = half4(tex6.SampleLevel(sam, pos, 0));
    half3 origin = half3(INPUT.SampleLevel(sam, pos, 0).rgb);

    half4 src7 = half4(0.013687534h, -0.08185164h, -0.04755438h, 0.290178h);
    src7 = MulAdd(max(a, half4(0)), half4x4(-0.22753362h, -0.08612073h, 0.33140692h, 0.08699529h, -0.18788953h, -0.056579117h, -0.12905197h, -0.06694621h, 0.054559365h, 0.15031597h, -0.13430363h, 0.021646025h, 0.14884405h, -0.0694291h, 0.26149413h, 0.11270503h), src7);
    src7 = MulAdd(max(b, half4(0)), half4x4(0.17876762h, -0.09637848h, 0.11285323h, 0.2004893h, 0.1317187h, -0.036162686h, 0.17958368h, -0.069625h, 0.28760737h, -0.12505141h, 0.12760694h, 0.047717955h, -0.16811855h, -0.16340709h, 0.13278298h, -0.08403954h), src7);
    src7 = MulAdd(max(c, half4(0)), half4x4(-0.21917523h, 0.079711854h, -0.28642535h, 0.2822416h, 0.03001489h, -0.014772918h, -0.3487396h, 0.10597145h, -0.013841082h, 0.17034237h, 0.10810282h, -0.08089695h, -0.22184245h, -0.59067357h, 0.44113398h, 0.13045649h), src7);
    src7 = MulAdd(max(d, half4(0)), half4x4(-0.29906932h, 0.013923749h, 0.2031124h, -0.11846688h, -0.13953634h, 0.08003455h, -0.10164494h, -0.21218559h, 0.10563715h, 0.31033117h, -0.075903505h, 0.047310907h, -0.37824214h, -0.14506383h, 0.11866701h, -0.21384487h), src7);
    src7 = MulAdd(max(e, half4(0)), half4x4(-0.1353849h, 0.19258606h, 0.063908584h, -0.2043788h, 0.27244982h, 0.1665306h, -0.29357895h, -0.22441709h, 0.18514316h, -0.17840464h, 0.20986097h, 0.14351055h, -0.057732623h, 0.42166704h, -0.23182064h, -0.4957248h), src7);
    src7 = MulAdd(max(f, half4(0)), half4x4(-0.34830126h, 0.109066755h, -0.28285867h, -0.048280068h, -0.12290918h, 0.04291651h, -0.047484186h, -0.03702595h, 0.23047262h, 0.09398974h, 0.022467108h, 0.08271034h, 0.3066665h, -0.54077h, 0.057771873h, 0.23194093h), src7);
    src7 = MulAdd(max(g, half4(0)), half4x4(-0.17731948h, -0.3175927h, 0.1452728h, 0.09396786h, -0.16433562h, -0.01833653h, -0.22345604h, -0.04161193h, -0.14827462h, 0.18544114h, -0.15544125h, -0.06179007h, 0.16989979h, -0.20985202h, 0.16391534h, -0.09447268h), src7);
    src7 = MulAdd(max(h, half4(0)), half4x4(-0.053878862h, -0.21034616h, 0.023831524h, 0.19772215h, 0.31647214h, 0.0126534775h, -0.19130844h, -0.049282108h, -0.21446131h, 0.067189045h, 0.09117449h, -0.25548774h, 0.12109098h, 0.22009392h, -0.3924665h, -0.13340388h), src7);
    src7 = MulAdd(max(i, half4(0)), half4x4(-0.16096684h, -0.18495405h, 0.10410178h, 0.0015673033h, -0.00183498h, -0.044303037h, -0.062745355h, -0.090802394h, 0.043269135h, 0.06924481h, -0.21367405h, -0.14619029h, 0.11555763h, -0.20292862h, 0.5799557h, 0.14739846h), src7);
    src7 = MulAdd(max(-a, half4(0)), half4x4(-0.21030277h, -0.09578802h, 0.013482288h, -0.21484336h, 0.12995781h, 0.40431052h, -0.3347856h, -0.18183486h, 0.15550353h, -0.04402301h, 0.4603779h, 0.14874357h, -0.07694621h, -0.053523075h, -0.19607326h, -0.10850742h), src7);
    src7 = MulAdd(max(-b, half4(0)), half4x4(-0.2347211h, 0.2697403h, -0.0634794h, -0.17925987h, 0.17231455h, 0.24999185h, -0.5208536h, -0.10491828h, -0.233575h, 0.52950364h, 0.0038063182h, -0.1380038h, 0.022935199h, 0.19369157h, 0.14586553h, 0.1938704h), src7);
    src7 = MulAdd(max(-c, half4(0)), half4x4(-0.10245223h, 0.34150192h, 0.25862157h, -0.20165509h, 0.5597771h, 0.114510864h, -0.122526556h, -0.04010975h, 0.1704679h, -0.23335956h, -0.16771887h, -0.03783455h, -0.056995615h, 0.24153493h, -0.08082429h, -0.24210933h), src7);
    src7 = MulAdd(max(-d, half4(0)), half4x4(-0.103466526h, 0.15278348h, -0.30526164h, -0.080755696h, 0.103505425h, 0.15862796h, 0.14696524h, -0.008358076h, -0.09180311h, -0.12505089h, 0.28052542h, -0.13551563h, 0.07528779h, -0.09636086h, -0.10369617h, 0.23656134h), src7);
    src7 = MulAdd(max(-e, half4(0)), half4x4(-0.25752836h, 0.099439755h, -0.30716348h, 0.035077725h, 0.023509016h, 0.23106368h, 0.05277125h, 0.34910464h, 0.088015385h, 0.26995596h, 0.1390645h, -0.40671825h, 0.18096298h, -0.100688554h, 0.5492049h, 0.2482101h), src7);
    src7 = MulAdd(max(-f, half4(0)), half4x4(0.41411775h, -0.107200556h, -0.13813478h, 0.13768874h, 0.27137747h, 0.06313619h, -0.08522967h, 0.03218302h, -0.03166121h, -0.3415683h, -0.52242h, -0.1741813h, -0.36956537h, 0.179129h, -0.09742935h, -0.11696616h), src7);
    src7 = MulAdd(max(-g, half4(0)), half4x4(-0.07975504h, 0.17964838h, 0.37122533h, 0.16064765h, 0.14309953h, 0.29473078h, 0.0926391h, -0.22333665h, 0.34612748h, -0.3387473h, 0.0077308523h, -0.07239449h, 0.18522519h, -0.21297298h, 0.11493978h, 0.16117814h), src7);
    src7 = MulAdd(max(-h, half4(0)), half4x4(-0.17402779h, 0.10023144h, 0.11712206h, 0.031971734h, 0.18713303h, 0.08736295h, 0.013007052h, -0.06943139h, -0.20102951h, -0.010721135h, -0.2562522h, 0.34877458h, -0.13732676h, -0.40258047h, 0.25824392h, 0.15720639h), src7);
    src7 = MulAdd(max(-i, half4(0)), half4x4(0.044494305h, 0.3296108h, 0.0017603852h, 0.09362289h, 0.38839245h, 0.40015858h, -0.13395199h, -0.044521853h, -0.56266373h, 0.251378h, 0.5005789h, -0.13106057h, -0.18491416h, -0.046887h, 0.067797676h, -0.14694957h), src7);

    half3 result = half3(-0.010478934h, -0.008364784h, -0.010246552h);
    result = MulAdd(max(src1, half4(0)), half4x3(-0.08837163h, -0.065234736h, -0.034704313h, 0.021405501h, 0.013663729h, 0.019249594h, 0.05328863h, 0.03580334h, 0.046457592h, -0.12216048h, 0.022547891h, 0.016400825h), result);
    result = MulAdd(max(-src1, half4(0)), half4x3(0.061996464h, 0.05631466h, 0.06808407h, -0.005013109h, -0.0044589997h, -0.032367796h, 0.016481603h, 0.13721058h, 0.14924648h, 0.020035887h, -0.07250003h, -0.08034037h), result);
    result = MulAdd(max(src2, half4(0)), half4x3(0.24078514h, 0.081361525h, 0.053420708h, -0.009353794h, -0.051077116h, -0.058007747h, -0.14071098h, 0.01035966h, 0.005308949h, -0.1489842h, -0.06711817h, -0.05552926h), result);
    result = MulAdd(max(-src2, half4(0)), half4x3(-0.13002375h, 0.012733757h, 0.017821986h, 0.17767483h, 0.20204604h, 0.1751779h, 0.12804912h, 0.07381453h, 0.05655911h, 0.17044514h, 0.07301451h, 0.06523978h), result);
    result = MulAdd(max(src3, half4(0)), half4x3(-0.1170986h, -0.05130371h, -0.027939914h, -0.16645707h, -0.121526904h, -0.09471366h, -0.04143118h, 0.026693767h, 0.034615446h, -0.084318705h, -0.064990036h, -0.054324172h), result);
    result = MulAdd(max(-src3, half4(0)), half4x3(0.12094524h, 0.09518409h, 0.07387219h, 0.062216382h, 0.053228356h, 0.031372335h, 0.072797105h, 0.026258165h, 0.009804673h, 0.120719045h, 0.073281154h, 0.056623302h), result);
    result = MulAdd(max(src4, half4(0)), half4x3(-0.11141495h, -0.11566289h, -0.10398725h, -0.0651895h, -0.06820691h, -0.054204144h, -0.032746475h, -0.008849683h, -0.007610222h, -0.024655705h, -0.048778858h, -0.041144755h), result);
    result = MulAdd(max(-src4, half4(0)), half4x3(0.058090195h, 0.07538767h, 0.059722915h, 0.044788487h, 0.04212742h, 0.027502589h, 0.04892866h, 0.015416752h, 0.008312418h, -0.011864114h, -0.0074752793h, -0.0060824654h), result);
    result = MulAdd(max(src5, half4(0)), half4x3(0.043446552h, 0.061971307h, 0.05758086h, -0.06379154h, -0.053758245h, -0.047204215h, 0.016307736h, 0.03423424h, 0.030179083h, 0.041445345h, 0.03843772h, 0.033059113h), result);
    result = MulAdd(max(-src5, half4(0)), half4x3(-0.003803544h, 0.0008906116h, -0.00059585314h, 0.102071285h, 0.11485224h, 0.10007254h, -0.074306004h, -0.08803551h, -0.07972321h, -0.030704215h, -0.021514274h, -0.009049376h), result);
    result = MulAdd(max(src6, half4(0)), half4x3(0.0066058086h, 0.0011408008h, 0.0016199006h, -0.03916473h, -0.042929266h, -0.04018418h, -0.03153446h, -0.039413508h, -0.034767237h, 0.113516055h, 0.12577052h, 0.113335624h), result);
    result = MulAdd(max(-src6, half4(0)), half4x3(0.02655948h, 0.041905303h, 0.03861737h, 0.048471425h, 0.049788587h, 0.050447535h, 0.12092813h, 0.13564217h, 0.12613249h, -0.0023508538h, 0.0012828974h, 0.0028730957h), result);
    result = MulAdd(max(src7, half4(0)), half4x3(0.0084758485h, 0.008800083h, 0.008206044h, -0.056123603h, -0.06610845h, -0.060320783h, -0.081793964h, -0.101638645h, -0.096699014h, -0.04402356h, -0.04177539h, -0.03829645h), result);
    result = MulAdd(max(-src7, half4(0)), half4x3(0.10676299h, 0.118409514h, 0.10618478h, -0.05880252h, -0.06488367h, -0.06432695h, 0.019221924h, 0.017602798h, 0.017413978h, -0.07512528h, -0.080483615h, -0.066218294h), result);

    OUTPUT[gxy] = float4(result + origin, 1);
}
