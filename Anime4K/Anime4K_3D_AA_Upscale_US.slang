// Anime4K 3D Graphics Anti-Aliased Upscaler (Ultra Small)
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

[bgfx::SIZE("INPUT_WIDTH * 2", "INPUT_HEIGHT * 2")]
[format("rgba8")]
RWTexture2D<float4> OUTPUT;

[bgfx::SAMPLER(FilterMode.POINT, AddressMode.CLAMP)]
SamplerState sam;

[bgfx::SAMPLER(FilterMode.LINEAR, AddressMode.CLAMP)]
SamplerState sam1;

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

[bgfx::EFFECT("Anime4K 3D AA Upscale US", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("2x upscaler with anti-aliasing for 3D graphics content. Ultra small variant offers fastest performance with basic quality.")]
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
                half4 result = half4(0.025272772h, 0.014345055h, -0.009859513h, 0.000597734h);
                result = MulAdd(src[i - 1][j - 1], half3x4(0.10005958h, 0.30363804h, -0.24045889h, -0.003466652h, 0.25860623h, 0.47408342h, -0.58965975h, 0.058167808h, 0.17228158h, 0.43657768h, -0.3982826h, -0.022539442h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.23593923h, 0.4692322h, 0.04355681h, 0.009586428h, -0.37485301h, 0.5885971h, 0.3236714h, -0.08301241h, -0.3188667h, 0.5608897h, 0.3396368h, 0.059106056h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(-0.15485556h, -0.11745722h, 0.042440087h, 0.5313071h, -0.24682014h, 0.00033858762h, -0.08202063h, 0.84100145h, -0.15803772h, -0.11368423h, -0.09765383h, 0.6991758h), result);
                result = MulAdd(src[i][j - 1], half3x4(0.21323937h, 0.07442176h, -0.10949712h, -0.05313448h, 0.44871446h, 0.16815953h, 0.07202329h, -0.05763504h, 0.12998791h, 0.06934043h, 0.044557367h, -0.00978054h), result);
                result = MulAdd(src[i][j], half3x4(0.40295616h, -0.7156766h, 0.7321813h, -0.54544497h, 0.44781828h, -1.1244348h, 0.7786728h, -0.91297877h, 0.52567977h, -0.81486106h, 0.56867415h, -0.68681335h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.020084642h, -0.072761856h, -0.13040084h, 0.063976064h, 0.18822637h, -0.096821584h, -0.06842927h, 0.18078656h, 0.05295053h, -0.18540566h, -0.1239999h, 0.0156137515h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(-0.6254935h, 0.0074730455h, 0.21930416h, 0.028796878h, -0.82789946h, 0.051125027h, 0.25597844h, 0.049207535h, -0.68400925h, -0.015768895h, 0.233402h, 0.021760475h), result);
                result = MulAdd(src[i + 1][j], half3x4(0.21823564h, -0.15992375h, -0.14845636h, -0.031485636h, 0.13821888h, -0.27466524h, -0.094343h, -0.07067512h, 0.20875643h, -0.20346795h, -0.12910774h, -0.052383807h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(0.001368614h, 0.17603171h, -0.36661625h, -0.0043979343h, 0.1381601h, 0.27952382h, -0.6743216h, 0.0067374213h, -0.023204552h, 0.21662682h, -0.3795221h, -0.025739884h), result);

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
                half4 result = half4(-0.012601902h, -0.0121468h, -0.027073797h, -0.0223602h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.08796357h, 0.028130328h, 0.073414765h, -0.029320398h, -0.07826724h, 0.012752971h, 0.06304871h, 0.082551956h, -0.052348416h, 0.010077275h, 0.0803755h, 0.16395038h, -0.08238233h, -0.0012038432h, -0.1297045h, -0.1087021h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.044162463h, -0.019727755h, -0.05845153h, -0.23984948h, 0.08363732h, -0.06774037h, 0.0234879h, 0.02139741h, 0.0028723166h, -0.07549135h, 0.0744662h, 0.109019615h, 0.03763121h, -0.060664024h, -0.03823593h, -0.015655363h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.026882887h, 0.124355234h, -0.005225512h, 0.053853527h, -0.004761375h, 0.07739831h, 0.007993726h, -0.024238527h, -0.035357814h, 0.022114292h, -0.026158875h, 0.047122046h, -0.021067293h, 0.041959677h, 0.008588816h, -0.006613815h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.037601672h, 0.010898833h, 0.05053419h, -0.0118405875h, 0.052177202h, 0.013291429h, -0.20246609h, -0.07192325h, -0.05164381h, -0.011278074h, -0.12394048h, -0.037769064h, 0.24392918h, 0.03289724h, 0.018663784h, 0.04071627h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.17768572h, -0.003431817h, 0.024597375h, -0.067222916h, -0.15119793h, -0.049984362h, 0.0588867h, 0.20031504h, -0.028296817h, -0.17337173h, 0.02136566h, 0.07842319h, -0.10203611h, 0.02128208h, 0.20057699h, 0.026265312h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.018206367h, -0.36731398h, -0.07842714h, -0.08946319h, 0.05601789h, -0.13398123h, -0.09766525h, 0.0051633804h, -0.004821273h, -0.060362365h, -0.08751827h, -0.01924666h, -0.01642196h, -0.084792316h, -0.021546558h, -0.01531331h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.003315341h, 0.003464535h, 0.023609636h, -0.029517155h, 0.023121882h, -0.033598952h, 0.032658506h, 0.072380014h, 0.038630765h, -0.020992903h, -0.09003304h, 0.048244834h, 0.17752261h, -0.023978172h, 0.7178278h, 0.09461632h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.010277829h, -0.0462686h, -0.024897251h, -0.02214524h, 0.1262903h, -0.15583614h, -0.50100106h, -0.04074772h, 0.0612536h, -0.17066137h, -0.15715116h, -0.020877155h, -0.062031068h, 0.4314311h, -0.008700501h, -0.030722365h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.12062004h, 0.055291675h, 0.041176047h, -0.034254536h, -0.04062085h, 0.14750236h, 0.100433215h, 0.024384778h, -0.02506444h, -0.0012329774h, 0.06715311h, 0.013158619h, -0.07343181h, 0.08929479h, 0.015891392h, 0.0014893904h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.00028356185h, 0.008408778h, 0.046833538h, -0.110735945h, 0.050230157h, -0.023995856h, -0.06471944h, -0.12666705h, 0.121487044h, -0.040447604h, -0.13425831h, -0.035763647h, 0.06327994h, 0.04542948h, 0.12984566h, 0.041735172h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.09654193h, 0.055733874h, 0.14149562h, 0.20103204h, -0.04256184h, 0.041129943h, -0.0997907h, 0.030775042h, 0.017492702h, 0.053436417h, -0.13472094h, -0.037674613h, -0.09461306h, 0.07363193h, 0.025130237h, -0.020962669h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.003966979h, -0.077911004h, -0.025530541h, -0.08657802h, 0.047928706h, -0.12820454h, -0.034780253h, 0.070523396h, 0.0991259h, -0.07432318h, -0.035848588h, 0.026542934h, -0.005886989h, -0.048655648h, 0.014799456h, -0.033676937h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.0040423325h, 0.011639387h, 0.014709128h, -0.100935176h, -0.03094238h, -0.0058094636h, 0.1256023h, 0.086693585h, -0.00840243h, -0.02635784h, -0.2395783h, 0.0055595445h, -0.104565054h, 0.05285065h, 0.092289336h, 0.12696597h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(-0.097862415h, 0.035469674h, -0.12026435h, -0.25865972h, 0.12508512h, -0.00648921h, -0.1848096h, -0.24143967h, -0.009432349h, -0.035211377h, -0.05589267h, -0.11565712h, 0.015937572h, 0.02717122h, -0.09954979h, -0.081140056h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.09073428h, 0.31426015h, 0.087145604h, -0.00073830306h, 0.013578701h, 0.032616604h, 0.038264107h, 0.07236385h, -0.012257218h, 0.040580798h, 0.08520396h, 0.004167174h, 0.02280993h, 0.113494344h, 0.027510444h, 0.029490784h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.02391937h, 0.0039571812h, -0.026116686h, -0.025334306h, 0.06904104h, 0.011511556h, -0.14147542h, 0.01224604h, 0.03788813h, -0.041387778h, -0.1523622h, 0.03650455h, 0.04693732h, 0.03091366h, 0.2839756h, 0.1779714h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.026292996h, 0.020397607h, 0.09354275h, 0.00044126343h, -0.047845h, 0.11368384h, 0.18426466h, 0.12002076h, -0.034070846h, 0.042704806h, -0.041553736h, 0.04446022h, -0.006331844h, 0.16227855h, 0.07832003h, -0.07068554h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.026658786h, -0.0079359505h, -0.04125044h, -0.10622727h, 0.06254047h, -0.36537018h, -0.10755624h, 0.011665703h, 0.025558028h, -0.087151h, -0.06987865h, 0.00023839885h, 0.03247968h, -0.053188834h, -0.004876301h, -0.06005079h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Reconstruction Conv-4x3x3x4, Depth-to-Space")]
[bgfx::PASS_IO("INPUT, tex2", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass3(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 outputPt = GetOutputPt();

    float2 pos = ((gxy >> 1) + 0.5f) * inputPt;

    float2 tpos = pos - 0.5f * inputPt;
    const half4 sr = half4(tex2.GatherRed(sam, tpos));
    const half4 sg = half4(tex2.GatherGreen(sam, tpos));
    const half4 sb = half4(tex2.GatherBlue(sam, tpos));
    const half4 sa = half4(tex2.GatherAlpha(sam, tpos));

    half4 a = half4(sr.w, sg.w, sb.w, sa.w);
    half4 b = half4(sr.x, sg.x, sb.x, sa.x);
    half4 c = half4(tex2.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(sr.z, sg.z, sb.z, sa.z);
    half4 e = half4(sr.y, sg.y, sb.y, sa.y);
    half4 f = half4(tex2.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex2.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half4 result = half4(-3.1127936e-05h, 3.3726166e-05h, 4.8580805e-05h, -9.541029e-06h);
    result = MulAdd(max(a, half4(0)), half4x4(-0.00055252935h, 0.0011350953h, -0.0016148019h, 0.0014946404h, -0.30635214h, -0.017596753h, -0.0036547943h, 0.016236471h, 0.005174489h, 0.0030302007h, 0.00019672248h, 0.0006430973h, 0.0007490077h, -0.0031795658h, -6.158733e-05h, 0.0006820584h), result);
    result = MulAdd(max(b, half4(0)), half4x4(0.15602079h, 0.011071071h, -0.0027609533h, -0.0034318874h, -0.0039016667h, 0.016504101h, -0.27816474h, -0.008282344h, 0.19063498h, 0.012465078h, 0.010091085h, -0.004841106h, -0.11758087h, -0.012808949h, 0.0067606894h, 0.005216566h), result);
    result = MulAdd(max(c, half4(0)), half4x4(0.013258877h, -0.014989483h, 0.22402754h, 0.013204027h, 0.00016207264h, -0.00042593342h, -0.00333761h, -0.0012207513h, 0.0033727325h, -0.007841196h, 0.16044731h, 0.00594871h, -0.0028581345h, 0.012616562h, -0.15928285h, -0.011812331h), result);
    result = MulAdd(max(d, half4(0)), half4x4(-0.0048872055h, -0.0011780986h, -0.0029523429h, 0.00082424335h, -0.0024385185h, -0.26525813h, 0.013532772h, -0.0008381766h, 0.0024996721h, 0.0022899017h, -0.0017697349h, -0.0010618394h, 0.0024938583h, 0.005421073h, 0.0028740794h, -0.007808829h), result);
    result = MulAdd(max(e, half4(0)), half4x4(-0.08293415h, 0.2659366h, -0.010839574h, 0.023423964h, 0.01725351h, -0.009252893h, -0.011632222h, -0.308242h, 0.0001496815h, 0.16104282h, -0.0069378703h, 0.00842848h, 0.085917845h, -0.18407243h, -0.006601597h, -0.027134055h), result);
    result = MulAdd(max(f, half4(0)), half4x4(-0.033873428h, -0.011743531h, -0.230377h, 0.116242796h, -0.0018527015h, -0.00853698h, 0.0059901997h, -0.006155517h, -0.009841329h, 0.006163952h, 0.014816026h, 0.18667653h, 0.016977048h, -0.0017093032h, 0.19695279h, -0.061764043h), result);
    result = MulAdd(max(g, half4(0)), half4x4(-0.0003514533h, -0.0069080726h, 0.0052108583h, -0.0016346197h, -0.0016860099h, 0.006002445h, -0.0022835485h, -0.0028219873h, 0.0005367275h, 0.0005437954h, 0.00059865275h, -0.00014915364h, -0.0032214937h, -0.00052043283h, -0.0031621973h, 0.0055843857h), result);
    result = MulAdd(max(h, half4(0)), half4x4(-0.006905302h, -0.20389622h, 0.01891904h, -0.018114902h, 0.00724176h, 0.011335843h, -0.0028616642h, 0.016452003h, -0.00013852821h, -0.00039706306h, 0.0011838446h, 0.0028873065h, 0.012857878h, 0.16889338h, -0.014114007h, 0.009388666h), result);
    result = MulAdd(max(i, half4(0)), half4x4(0.0040798862h, 0.002933288h, -0.016012201h, -0.14650294h, -0.0017411204h, 0.0017980475h, 0.00056705566h, -0.0003218331h, -0.0014291195h, -0.0062614805h, 0.00082543516h, -0.00397049h, -0.004496662h, 0.0008032309h, 0.0049529593h, 0.117166765h), result);

    pos -= 0.5f * outputPt;
    OUTPUT[gxy] = float4(result.x + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.x;
    pos.x += outputPt.x;
    OUTPUT[gxy] = float4(result.y + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    ++gxy.y;
    pos.y += outputPt.y;
    OUTPUT[gxy] = float4(result.w + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);

    --gxy.x;
    pos.x -= outputPt.x;
    OUTPUT[gxy] = float4(result.z + half3(INPUT.SampleLevel(sam1, pos, 0).rgb), 1);
}
