// Anime4K Restore Soft S
// Based on Anime4K project by bloc97

import bgfx;

#ifdef BG_FP16
#pragma warning(disable: 3557)
#endif

Texture2D INPUT;

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

[bgfx::EFFECT("Anime4K Restore Soft S", 2)]
[bgfx::CATEGORY("Anime4K")]
[bgfx::DESCRIPTION("Soft detail restoration for anime content. Small variant offers fastest performance with basic quality.")]
[bgfx::FP16]
[bgfx::PASS(1, "Conv-4x3x3x3")]
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
                half4 result = half4(0.0113532655h, -0.06449327h, 0.035503868h, 0.5683031h);
                result = MulAdd(src[i - 1][j - 1], half3x4(0.10922428h, -0.16249932h, 0.15452726h, -0.15669551h, 0.053448875h, -0.16528402h, 0.01697721h, -0.049275912h, 0.20947173h, -0.10576949h, 0.19738325h, -0.025417482h), result);
                result = MulAdd(src[i - 1][j], half3x4(-0.3285196h, 0.15909512h, -0.5273671h, 0.23778777h, -0.40508887h, -0.0609677h, -0.4188177h, 0.11137456h, -0.24131267h, 0.10453423h, -0.36216277h, 0.053446792h), result);
                result = MulAdd(src[i - 1][j + 1], half3x4(0.23072472h, -0.082083695h, -0.0041477727h, -0.09136237h, 0.11958912h, -0.312698h, -0.15842685h, -0.013882424h, 0.10933724h, 0.017880991h, -0.022167003h, 0.014662608h), result);
                result = MulAdd(src[i][j - 1], half3x4(-0.2789985h, 0.054727737h, 0.22577816h, -0.49625716h, -0.48472273h, -0.011525487h, 0.5354349h, -0.08814955h, -0.27021924h, -0.044563178h, 0.008232271h, -0.13480483h), result);
                result = MulAdd(src[i][j], half3x4(-0.18203105h, 0.09277001h, 0.27071548h, -0.17773713h, -0.4335171h, 1.2275106h, -0.07663438h, -0.29020032h, 0.011992759h, 0.060106967h, 0.11002492h, -0.046098012h), result);
                result = MulAdd(src[i][j + 1], half3x4(0.08363418h, 0.063420765h, -0.10278259h, 0.09357691h, 0.38670546h, 0.13577081h, 0.048631024h, -0.024960777h, 0.0846784h, -0.057097007h, 0.06049236h, 0.042082917h), result);
                result = MulAdd(src[i + 1][j - 1], half3x4(0.12315548h, -0.056513585h, -0.09826642h, -0.17079762h, 0.06479095h, -0.36984903h, -0.12512982h, 0.042867575h, 0.08360464h, 0.12835538h, -0.005067881h, 0.02542005h), result);
                result = MulAdd(src[i + 1][j], half3x4(0.18997705h, 0.086363226h, -0.0007131526h, 0.19858918h, 0.39745626h, -0.0090341605h, 0.27864447h, 0.20052041h, 0.010576528h, -0.089242525h, -0.025109483h, -0.030768145h), result);
                result = MulAdd(src[i + 1][j + 1], half3x4(0.05427315h, -0.060894873h, 0.06548642h, 0.095537595h, 0.29116166h, -0.16159569h, -0.13293959h, -0.112566955h, 0.0059667625h, 0.016041303h, 0.03831561h, 0.09869594h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(2, "Conv-4x3x3x8")]
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
                half4 result = half4(-0.106538564h, -0.065693766h, -0.03790106h, 0.04776706h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(-0.027102098h, 0.2640691h, 0.1169015h, 0.030902913h, 0.15404584h, 0.1361459h, -0.38066056h, 0.096569136h, -0.111836195h, -0.0051853824h, -0.0996669h, -0.23538585h, -0.07060754h, -0.18889332h, -0.10793357h, -0.15154232h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(0.1378689h, 0.21024452h, 0.010976513h, 0.0179521h, -0.05993059h, -0.28364083h, 0.24486947h, 0.21347582h, -0.12522404h, -0.16091396h, 0.15499291h, 0.08353191h, -0.03342411h, -0.08964405h, 0.25111282h, -0.07550899h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.06398718h, 0.05763278h, 0.021394925h, 0.14780094h, -0.033050716h, 0.03346528h, -0.0846797h, 0.0125302235h, 0.18018652h, 0.24586707h, 0.050538495h, 0.09879243h, -0.100035876h, 0.043505374h, 0.042692907h, -0.08768257h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.11572878h, 0.0545887h, 0.16437739h, 0.2775331h, 0.10323911h, -0.18938646h, -0.17097469h, -0.188723h, 0.085762165h, 0.14605838h, -0.15568069h, -0.16947642h, 0.09042493h, -0.087587915h, -0.041969277h, 0.27252352h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(0.21475963h, -0.018211678h, -0.5711054h, -0.09235345h, -0.20367791h, -0.23041399h, 0.16346097h, 0.007901888h, 0.12542121h, 0.16807431h, 0.09862575h, 0.16968751h, 0.28490388h, 0.40945014h, -0.22364445h, 0.14460565h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(0.27512726h, 0.14046481h, -0.17684339h, 0.102218024h, -0.10503195h, 0.3080809h, 0.03681373h, 0.2668656h, -0.093752496h, -0.07476867h, 0.19900662h, 0.06028286h, -0.19815882h, -0.0584525h, 0.027984729h, -0.02143819h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(-0.16829525h, -0.06818115h, 0.0006509334h, 0.01163159h, 0.18918815h, -0.10731989h, -0.008126929h, -0.47991323h, -0.11022971h, 0.19150843h, 0.05272113h, -0.34417602h, 0.022882428h, 0.1774031h, 0.062597334h, -0.09915319h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.32131585h, 0.05668815h, -0.34203658h, 0.05542482h, -0.008077225h, 0.009148517h, 0.10953332h, -0.050969962h, 0.09904077h, 0.46938205h, -0.5148919h, -0.22275375h, -0.10536104h, -0.23662373h, 0.002147416h, -0.14256701h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(-0.19335353h, -0.103732094h, 0.17156832h, 0.0059756916h, -0.118641876h, 0.14529023h, -0.18662338h, 0.0447326h, 0.026719248h, 0.042491894h, 0.026437795h, 0.05601309h, 0.08645617h, 0.08365193h, -0.039582565h, 0.16612953h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.014315469h, 0.012588422h, 0.037587024h, 0.08707526h, -0.08064868h, -0.28149533h, 0.27326405h, 0.21468583h, -0.04278333h, 0.29369017h, 0.18653142h, 0.035729136h, 0.079363555h, 0.30725953h, 0.0147137h, 0.08527481h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(0.06659263h, 0.03452449h, -0.33752796h, 0.0066543026h, 0.48697233h, 0.019602561h, -0.32033685h, -0.20538871h, 0.3089118h, 0.4315903h, -0.13524854h, -0.10791581h, 0.3315688h, 0.13135147h, -0.26904663h, 0.142365h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(0.13619833h, 0.045271892h, -0.029841429h, 0.010704955h, -0.29257727h, -0.10563375h, 0.35345638h, -0.06734038h, -0.043791633h, -0.0056891907h, -0.078411415h, 0.075443126h, -0.05746597h, -0.19959894h, -0.12797245h, 0.18837726h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(0.25673476h, 0.120482095h, -0.23827696h, -0.13557845h, 0.300447h, -0.3008584h, -0.13834439h, 0.5459493h, -0.26155484h, 0.06905137h, 0.16247983h, 0.039960653h, -0.023218757h, 0.07977591h, -0.11354706h, -0.25831422h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.0842605h, 0.282916h, 0.14062001h, 0.06356874h, 0.55912817h, 0.1743876h, -0.30324093h, 0.052068707h, -0.20756413h, 0.27321506h, -0.26560605h, -0.27695876h, -0.3927334h, -0.5439608h, 0.39293098h, -0.001130203h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(-0.021890296h, -0.12703396h, 0.06660714h, -0.03164527h, 0.0018722567h, -0.26552317h, 0.06978973h, -0.24030049h, 0.46008193h, 0.5595346h, 0.081981994h, -0.038414747h, -0.010446991h, -0.56102365h, -0.079274766h, -0.01851302h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(0.052988984h, 0.030581746h, -0.06868741h, 0.21545182h, -0.5706256h, -0.0034910638h, 0.48361364h, 0.9020033h, -0.02242781h, -0.13256042h, 0.08997955h, 0.21001706h, -0.059571438h, -0.040119104h, -0.05029196h, -0.127414h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.08275339h, -0.05999088h, 0.11068767h, 0.014646892h, -0.041986465h, 0.1028236h, -0.17218924h, 0.026559748h, -0.17412743h, -0.38364175h, 0.17410514h, 0.13038695h, 0.23155633h, 0.2655843h, 0.045085523h, 0.13005458h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.013383197h, -0.064526096h, 0.049046878h, 0.015992291h, 0.123987064h, 0.0104690585h, 0.07065378h, -0.009824511h, -0.036109775h, 0.13384768h, 0.29676288h, -0.39475223h, -0.009368096h, -0.05666906h, -0.09132696h, -0.082638375h), result);

                tex2_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(3, "Conv-4x3x3x8")]
[bgfx::PASS_IO("tex2", "tex1_UAV")]
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
                half4 result = half4(-0.0063428865h, 0.0057986965h, -0.12526293h, -0.059240736h);
                result = MulAdd(max(src[i - 1][j - 1], half4(0)), half4x4(0.024004154h, -0.26474997h, -0.5256586h, 0.051624652h, -0.16621786h, 0.2964122h, 0.6044247h, -0.14335106h, 0.17002718h, -0.2679876h, -0.30162668h, 0.1273794h, -0.17601459h, -0.1782376h, 0.104725115h, -0.16351137h), result);
                result = MulAdd(max(src[i - 1][j], half4(0)), half4x4(-0.121676154h, 0.047741555h, -0.06738679h, -0.056402843h, 0.004424971h, -0.35099635h, -0.073440626h, 0.039784692h, 0.15204315h, -0.1165704h, 0.11231046h, -0.27369732h, 0.33737272h, -0.11880767h, 0.09637475h, -0.14709689h), result);
                result = MulAdd(max(src[i - 1][j + 1], half4(0)), half4x4(-0.017987821h, -0.08798823h, -0.062515825h, -0.046803873h, -0.05871703h, 0.27013004h, 0.19397618h, -0.052147817h, 0.003271283h, -0.0029015478h, -0.07390092h, -0.09348337h, -0.1574738h, 0.06750957h, -0.07661155h, 0.054327156h), result);
                result = MulAdd(max(src[i][j - 1], half4(0)), half4x4(-0.15215784h, -0.72508365h, -0.3202069h, 0.20295432h, -0.19125701h, 0.021401431h, -0.051837035h, -0.025939213h, 0.25565025h, -0.12872623h, 0.13169816h, 0.27377388h, -0.008718429h, -0.05864064h, 0.028844763h, 0.1144993h), result);
                result = MulAdd(max(src[i][j], half4(0)), half4x4(-0.30012092h, -0.1322455h, -0.11868545h, 0.09857058h, 0.082795605h, -0.075334676h, -0.3752773h, -0.02918163h, -0.67764h, -0.38598236h, -0.21023573h, 0.38274166h, -0.07398165h, -0.07213789h, -0.28427607h, 0.1266569h), result);
                result = MulAdd(max(src[i][j + 1], half4(0)), half4x4(-0.37507388h, 0.18809201h, -0.21982779h, 0.27208912h, 0.022066567h, -0.27627763h, 0.12345216h, -0.30041683h, 0.017002959h, -0.091398515h, -0.25207692h, -0.29253414h, -0.08231422h, -0.14665812h, -0.07868529h, -0.24562219h), result);
                result = MulAdd(max(src[i + 1][j - 1], half4(0)), half4x4(0.08686712h, 0.080837384h, 0.20736577h, 0.008233064h, 0.14957365h, 0.21801959h, -0.04870689h, 0.42149112h, 0.27255878h, 0.33320278h, -0.08467146h, 0.10381615h, 0.055278245h, 0.085710146h, 0.009097151h, 0.29092705h), result);
                result = MulAdd(max(src[i + 1][j], half4(0)), half4x4(0.0012207404h, -0.023874281h, -0.027035477h, 0.005157451h, 0.19330226h, 0.33711615h, -0.16495204h, 0.549021h, 0.44879642h, 0.1978837h, -0.20492741h, 0.28099406h, 0.2631811h, 0.40786585h, -0.055340275h, 0.2575511h), result);
                result = MulAdd(max(src[i + 1][j + 1], half4(0)), half4x4(0.29127392h, -0.06287165h, 0.12715077h, 0.14784902h, -0.3183704h, 0.42057636h, -0.11483724h, -0.3019506h, 0.010730576h, 0.29091576h, -0.046116166h, -0.23528357h, -0.0037143505h, 0.1191774h, -0.06084074h, 0.011641706h), result);
                result = MulAdd(max(-src[i - 1][j - 1], half4(0)), half4x4(-0.2579205h, 0.036545023h, 0.11691888h, 0.04996418h, 0.21318026h, 0.21370813h, -0.14114271h, 0.031217605h, -0.06979331h, -0.0690704h, 0.04618086h, 0.025164584h, -0.10994228h, 0.109930746h, 0.103678934h, 0.12193115h), result);
                result = MulAdd(max(-src[i - 1][j], half4(0)), half4x4(-0.19843774h, -0.11237926h, 0.007291354h, 0.16480611h, -0.15669724h, 0.46283355h, 0.077065215h, 0.112273656h, 0.17143534h, -0.19934891h, -0.25481275h, 0.034591813h, -0.27032652h, -0.2702769h, 0.04816228h, -0.031614583h), result);
                result = MulAdd(max(-src[i - 1][j + 1], half4(0)), half4x4(-0.16307239h, -0.11295217h, 0.05861256h, 0.14225823h, -0.015648091h, 0.11741865h, 0.113366075h, 0.023935538h, 0.19560932h, -0.10553561h, -0.042583376h, -0.048160724h, -0.3116519h, 0.13957061h, -0.0044852323h, -0.015472912h), result);
                result = MulAdd(max(-src[i][j - 1], half4(0)), half4x4(-0.15629178h, 0.06463271h, -0.13176678h, 0.025518289h, -0.021733627h, 0.22236359h, 0.019508492h, -0.11629477h, 0.10801276h, -0.021957984h, -0.11272639h, -0.03615053h, -0.121420704h, 0.2520835h, 0.043395765h, 0.1699031h), result);
                result = MulAdd(max(-src[i][j], half4(0)), half4x4(0.2886654h, 0.21755892h, 0.21757497h, 0.08442575h, -0.109903164h, -0.67295986h, 0.22886126h, -0.027185453h, 0.3761606h, 0.23199768h, 0.05908783h, -0.1496158h, 0.10832971h, -0.3530352h, 0.20234483h, -0.07615918h), result);
                result = MulAdd(max(-src[i][j + 1], half4(0)), half4x4(0.11043024h, 0.18943349h, 0.42394367h, 0.029350199h, -0.15085667h, 0.020204183h, -0.081609115h, 0.07907012h, 0.33805525h, 0.0066280114h, 0.0018284445h, 0.022983696h, 0.004984607h, 0.0429299h, -0.14568979h, -0.29143327h), result);
                result = MulAdd(max(-src[i + 1][j - 1], half4(0)), half4x4(-0.16376027h, -0.20387048h, 0.06522074h, 0.17484841h, -0.13885716h, -0.04380927h, -0.03535832h, -0.16978237h, -0.004799155h, -0.25407305h, -0.039976966h, -0.011992087h, -0.22535577h, -0.09583549h, 0.0334331h, 0.016292758h), result);
                result = MulAdd(max(-src[i + 1][j], half4(0)), half4x4(-0.38688713h, -0.20232083h, 0.23887886h, -0.10438324h, -0.24170811h, -0.074868314h, 0.03977399h, -0.22810821h, -0.08257971h, -0.11902456h, 0.106009185h, -0.078289054h, -0.11932821h, 0.024207884h, 0.10070917h, 0.79348284h), result);
                result = MulAdd(max(-src[i + 1][j + 1], half4(0)), half4x4(-0.4018743h, 0.050456528h, 0.035341598h, -0.03788609h, 0.12964934h, -0.44461823h, 0.029031694h, 0.29604837h, -0.102386944h, -0.13805065h, 0.0055692918h, 0.14659804h, -0.22499937h, 0.14680648h, -0.3443954h, -0.06994176h), result);

                tex1_UAV[destPos] = result;
            }
        }
    }
}

[bgfx::PASS(4, "Conv-3x3x3x8")]
[bgfx::PASS_IO("INPUT, tex1", "OUTPUT")]
[bgfx::BLOCK_SIZE(16, 16)]
[shader("compute")]
[numthreads(8, 8, 1)]
void Pass4(uint3 tid: SV_DispatchThreadID)
{
    uint2 gxy = (Swizzle8x8((tid.y % 8) * 8 + (tid.x % 8)) << 1) + (tid.xy / 8) * 16;

    const uint2 outputSize = GetOutputSize();
    if (gxy.x >= outputSize.x || gxy.y >= outputSize.y)
    {
        return;
    }

    float2 inputPt = GetInputPt();
    float2 pos = (gxy + 0.5f) * inputPt;

    half4 a = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, -inputPt.y), 0));
    half4 b = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, 0), 0));
    half4 c = half4(tex1.SampleLevel(sam, pos + float2(-inputPt.x, inputPt.y), 0));
    half4 d = half4(tex1.SampleLevel(sam, pos + float2(0, -inputPt.y), 0));
    half4 e = half4(tex1.SampleLevel(sam, pos, 0));
    half4 f = half4(tex1.SampleLevel(sam, pos + float2(0, inputPt.y), 0));
    half4 g = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, -inputPt.y), 0));
    half4 h = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, 0), 0));
    half4 i = half4(tex1.SampleLevel(sam, pos + float2(inputPt.x, inputPt.y), 0));

    half3 result = half3(-0.008303841h, -0.008251826h, -0.0069884053h);
    result = MulAdd(max(a, half4(0)), half4x3(0.08631539h, 0.09499331h, 0.065609254h, -0.023760278h, -0.027293118h, -0.022839671h, -0.012447854h, -0.008565141h, -0.012041815h, -0.033292875h, -0.031266093h, -0.02874347h), result);
    result = MulAdd(max(b, half4(0)), half4x3(0.08709062h, 0.09760889h, 0.08988583h, -0.09099671h, -0.102120616h, -0.098076016h, 0.057814583h, 0.06999608h, 0.05961344h, 0.12246188h, 0.1319784h, 0.12254915h), result);
    result = MulAdd(max(c, half4(0)), half4x3(0.07694916h, 0.0822054h, 0.07549296h, -0.046808865h, -0.051509347h, -0.035890795h, 0.01599848h, 0.014677793h, 0.0086143715h, 0.033142705h, 0.0426565h, 0.035911378h), result);
    result = MulAdd(max(d, half4(0)), half4x3(-0.0008269902h, 0.0009082343h, 0.014101725h, 0.0006387551h, 0.005079344h, -0.013034868h, 0.013909732h, 0.011026747h, 0.012485332h, 0.027028518h, 0.022164145h, 0.03183532h), result);
    result = MulAdd(max(e, half4(0)), half4x3(-0.33575395h, -0.36700967h, -0.34140685h, 0.35850254h, 0.37535715h, 0.34613726h, -0.12680013h, -0.1256115h, -0.112494245h, -0.061541136h, -0.059120018h, -0.06552594h), result);
    result = MulAdd(max(f, half4(0)), half4x3(-0.047570463h, -0.050335366h, -0.04665491h, -0.110970475h, -0.12363716h, -0.11072252h, 0.041563414h, 0.059771337h, 0.045290247h, -0.17999935h, -0.19700716h, -0.17459513h), result);
    result = MulAdd(max(g, half4(0)), half4x3(0.078488424h, 0.07483357h, 0.08347933h, -0.0063715233h, 0.00035415235h, -0.010886946h, 0.031237155h, 0.02512343h, 0.034399323h, -0.023146842h, -0.026732154h, -0.027644241h), result);
    result = MulAdd(max(h, half4(0)), half4x3(-0.05906883h, -0.06784104h, -0.04506148h, -0.003939601h, -0.0011749315h, -0.006256036h, -0.1662408h, -0.16871658h, -0.16598499h, 0.051277652h, 0.04837499h, 0.05120855h), result);
    result = MulAdd(max(i, half4(0)), half4x3(0.08158806h, 0.08674548h, 0.07437206h, -0.05765347h, -0.06196418h, -0.057311118h, 0.26747537h, 0.2668808h, 0.2389857h, -0.010376844h, -0.01690028h, -0.008414153h), result);
    result = MulAdd(max(-a, half4(0)), half4x3(0.030539425h, 0.02415435h, 0.039969034h, 0.006491679h, 0.014436586h, 0.005435709h, -0.0058292216h, -0.013982021h, -0.011243379h, 0.025942149h, 0.015361476h, 0.019134998h), result);
    result = MulAdd(max(-b, half4(0)), half4x3(-0.06322247h, -0.07146787h, -0.06673042h, 0.028702464h, 0.039047733h, 0.039646607h, -0.072553575h, -0.08046175h, -0.07027197h, -0.1447189h, -0.1539398h, -0.1466465h), result);
    result = MulAdd(max(-c, half4(0)), half4x3(-0.046430312h, -0.054549117h, -0.048076343h, 0.032971155h, 0.02980819h, 0.029172963h, -0.017612953h, -0.015100736h, -0.01202649h, -0.026717246h, -0.028401854h, -0.034548033h), result);
    result = MulAdd(max(-d, half4(0)), half4x3(-0.0020459262h, -0.0008748501h, -0.012601956h, 0.0054226154h, 0.008867029h, 0.018921215h, -0.0021330053h, -0.0036601655h, -0.0022091097h, -0.08636891h, -0.10203159h, -0.09741449h), result);
    result = MulAdd(max(-e, half4(0)), half4x3(0.07306159h, 0.08245483h, 0.06548199h, -0.1933229h, -0.20326294h, -0.19189309h, 0.107496604h, 0.11584994h, 0.10907522h, 0.30877885h, 0.31297725h, 0.30890995h), result);
    result = MulAdd(max(-f, half4(0)), half4x3(0.03192904h, 0.035112645h, 0.033732817h, 0.074100636h, 0.08349646h, 0.06659352h, -0.1136165h, -0.12470947h, -0.11192198h, 0.14465587h, 0.16328491h, 0.13984151h), result);
    result = MulAdd(max(-g, half4(0)), half4x3(-0.05098033h, -0.053096622h, -0.05533725h, 0.0045651463h, -0.007682458h, 0.0026934785h, -0.021199327h, -0.016210148h, -0.030939564h, -0.031621892h, -0.046702545h, -0.02647333h), result);
    result = MulAdd(max(-h, half4(0)), half4x3(0.055801813h, 0.06430485h, 0.05052402h, 0.0241233h, 0.013879883h, 0.017344628h, 0.08707151h, 0.10031039h, 0.095042154h, -0.109053336h, -0.11414017h, -0.111838564h), result);
    result = MulAdd(max(-i, half4(0)), half4x3(0.030582374h, 0.03604719h, 0.040417343h, 0.038665913h, 0.036998056h, 0.030004544h, 0.09209076h, 0.10010001h, 0.08389406h, -0.014655714h, -0.0074866647h, -0.012227013h), result);

    result += half3(INPUT.SampleLevel(sam, pos, 0).rgb);

    OUTPUT[gxy] = float4(result, 1);
}
